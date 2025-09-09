import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'store_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Ayrı form key'leri - GlobalKey hatası düzeltildi
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Login.md ADIM 3: Kullanıcı kayıt sistemi
  Future<void> _register() async {
    print('🔵 Register method called');

    if (!_registerFormKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      print('🔵 Registering user: $email');

      // Login.md ADIM 3C: Davet kontrolü
      final invitation = await _checkInvitation(email);

      if (invitation != null) {
        print('🟢 Found invitation for: $email');
        // SENARYO A: Davetli kullanıcı
        await _handleInvitedUserRegistration(
            email, password, name, phone, invitation);
      } else {
        print('🟡 No invitation found for: $email - Normal user registration');
        // SENARYO B: Normal kullanıcı (yeni mağaza sahibi)
        await _handleNormalUserRegistration(email, password, name, phone);
      }

      print('✅ Registration completed successfully');
    } catch (e) {
      print('❌ Registration error: $e');
      _showError('Kayıt hatası: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Login.md ADIM 3C: Davet kontrol sistemi
  Future<Map<String, dynamic>?> _checkInvitation(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('store_invitations')
          .where('email', isEqualTo: email)
          .where('status',
              isEqualTo:
                  'accepted') // Login.md'ye göre 'accepted' status aranır
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Invitation check error: $e');
      return null;
    }
  }

  // Login.md SENARYO A: Davetli kullanıcı kayıt işlemi
  Future<void> _handleInvitedUserRegistration(String email, String password,
      String name, String phone, Map<String, dynamic> invitation) async {
    try {
      // 1. Firebase Authentication hesap oluştur
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed');
      }
      final userId = user.uid;
      final storeId = invitation['storeId'];
      final role = invitation['role'] ?? 'staff';

      // 2. User bilgilerini kaydet
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'storeId': storeId, // Davet edilen mağaza
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // 3. Mağaza üyelerine ekle
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('members')
          .doc(userId)
          .set({
        'email': email,
        'name': name,
        'role': role,
        'status': 'accepted',
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 4. Provider'ları güncelle ve yönlendir
      if (mounted) {
        // 5. Direkt dashboard'a git - Artık mağaza sahibi ile birlikte çalışıyor!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );

        _showSuccess('Hoş geldiniz! Mağaza takımına katıldınız.');
      }
    } catch (e) {
      print('❌ Invited user registration error: $e');
      throw e; // Re-throw to be caught by parent function
    }
  }

  // Login.md SENARYO B: Normal kullanıcı kayıt işlemi
  Future<void> _handleNormalUserRegistration(
      String email, String password, String name, String phone) async {
    try {
      // 1. Firebase Authentication hesap oluştur
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed');
      }
      final userId = user.uid;
      final storeId = 'store_$userId'; // YENİ mağaza ID'si

      // 2. User bilgilerini kaydet
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'name': name,
        'phone': phone,
        'role': 'owner',
        'storeId': storeId, // YENİ mağaza ID'si
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // 3. YENİ mağaza oluştur
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
        'ownerId': userId,
        'name': '', // Boş - kullanıcı dolduracak
        'address': '', // Boş - kullanıcı dolduracak
        'phone': '', // Boş - kullanıcı dolduracak
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Kendini mağaza sahibi olarak ekle
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('members')
          .doc(userId)
          .set({
        'email': email,
        'name': name,
        'role': 'owner',
        'status': 'owner',
        'userId': userId,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 5. Yönlendir
      if (mounted) {
        // 6. Mağaza kurulum sayfasına git - Mağaza bilgilerini dolduracak!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StoreSetupScreen()),
        );

        _showSuccess('Hoş geldiniz! Mağazanızı kuralım.');
      }
    } catch (e) {
      print('❌ Normal user registration error: $e');
      throw e; // Re-throw to be caught by parent function
    }
  }

  // Giriş yapma işlemi
  Future<void> _login() async {
    print('🔵 Login method called');

    if (!_loginFormKey.currentState!.validate()) {
      print('❌ Login form validation failed');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      print('🔵 Attempting login for: $email');

      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed - no user returned');
      }

      print('✅ Login successful for: ${user.email}');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      print('❌ Login error: $e');
      _showError('Giriş hatası: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo ve başlık
                  const Icon(
                    Icons.inventory_2,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'StockPro',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stok Yönetim Sistemi',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Ana kart
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Tab bar
                        Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Giriş Yap'),
                              Tab(text: 'Kayıt Ol'),
                            ],
                            labelColor: const Color(0xFF2A5298),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: const Color(0xFF2A5298),
                          ),
                        ),

                        // Tab content
                        Container(
                          constraints: BoxConstraints(
                            minHeight: 400,
                            maxHeight: MediaQuery.of(context).size.height * 0.7,
                          ),
                          padding: const EdgeInsets.all(24),
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Giriş formu
                              SingleChildScrollView(child: _buildLoginForm()),
                              // Kayıt formu
                              SingleChildScrollView(
                                  child: _buildRegisterForm()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hoş Geldiniz',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2A5298),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-posta',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'E-posta adresi gerekli';
              }
              if (!value.contains('@')) {
                return 'Geçerli bir e-posta adresi girin';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şifre gerekli';
              }
              if (value.length < 6) {
                return 'Şifre en az 6 karakter olmalı';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Login button
          ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A5298),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Giriş Yap',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Hesap Oluştur',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2A5298),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Name field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Ad Soyad',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ad soyad gerekli';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Phone field
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Telefon',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Telefon numarası gerekli';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-posta',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Bu önemli! Davet kontrolü için kullanılır.',
              helperStyle: const TextStyle(color: Color(0xFF2A5298)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'E-posta adresi gerekli';
              }
              if (!value.contains('@')) {
                return 'Geçerli bir e-posta adresi girin';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şifre gerekli';
              }
              if (value.length < 6) {
                return 'Şifre en az 6 karakter olmalı';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Confirm password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Şifre Tekrar',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şifre tekrarı gerekli';
              }
              if (value != _passwordController.text) {
                return 'Şifreler eşleşmiyor';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Register button
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A5298),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Kayıt Ol',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
