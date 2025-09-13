import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Beni hatırla için
import '../services/store_selection_service.dart'; // ✅ Store selection düzeltmesi için
import 'dashboard_screen.dart';
import 'store_setup_screen.dart';
import 'main_screen.dart';

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
  bool _rememberMe = false; // ✅ Beni hatırla checkbox'ı için

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAutoLogin(); // ✅ Otomatik giriş kontrolü
  }

  // ✅ Otomatik giriş kontrolü
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('saved_email');

    if (rememberMe && savedEmail != null) {
      // Firebase Auth zaten giriş yapmış kullanıcıyı hatırlıyor mu kontrol et
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email == savedEmail) {
        print('🔄 Auto-login successful for: $savedEmail');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      }
    }
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

      // Login.md ADIM 3C: Anonymous auth ile davet kontrolü
      print('🔍 Starting anonymous auth for invitation check...');
      await FirebaseAuth.instance.signInAnonymously();
      print('✅ Anonymous auth successful, checking invitations...');

      final invitation = await _checkInvitation(email);

      // Anonymous kullanıcıyı çıkar
      await FirebaseAuth.instance.signOut();
      print('📝 Anonymous user signed out');

      // Şimdi gerçek Firebase Auth hesap oluştur
      UserCredential tempUserCredential;
      try {
        tempUserCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        print('✅ Real Firebase Auth account created');
      } catch (authError) {
        if (authError.toString().contains('email-already-in-use')) {
          print('🟡 Email already exists, signing in...');
          try {
            tempUserCredential = await FirebaseAuth.instance
                .signInWithEmailAndPassword(email: email, password: password);
            print('✅ Signed in with existing account');
          } catch (signInError) {
            print('❌ Sign in failed: $signInError');
            throw Exception(
                'Bu email zaten kayıtlı ancak şifre yanlış. Lütfen doğru şifreyi girin.');
          }
        } else {
          print('❌ Firebase Auth error: $authError');
          throw authError;
        }
      }

      if (invitation != null) {
        print('🟢 Found invitation for: $email');
        // SENARYO A: Davetli kullanıcı
        await _handleInvitedUserRegistration(
            email, password, name, phone, invitation, tempUserCredential);
      } else {
        print('🟡 No invitation found for: $email - Normal user registration');
        // SENARYO B: Normal kullanıcı (yeni mağaza sahibi)
        await _handleNormalUserRegistration(
            email, password, name, phone, tempUserCredential);
      }

      print('✅ Registration completed successfully');
    } catch (e) {
      print('❌ Registration error: $e');
      print('❌ Full error stack trace: ${e.toString()}');
      if (e.toString().contains('email-already-in-use')) {
        _showError(
            'Bu e-posta adresi zaten kayıtlı. Lütfen giriş yapmayı deneyin.');
      } else {
        _showError('Kayıt hatası: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Login.md ADIM 3C: Davet kontrol sistemi
  Future<Map<String, dynamic>?> _checkInvitation(String email) async {
    try {
      print('🔍 Checking invitations for: $email');

      // ✅ ÖNCELİKLE TÜM DAVETLERİ KONTROL ET (debug için)
      final allInvitations = await FirebaseFirestore.instance
          .collection('store_invitations')
          .where('email', isEqualTo: email)
          .get();

      print(
          '📋 Total invitations found for $email: ${allInvitations.docs.length}');
      for (var doc in allInvitations.docs) {
        final data = doc.data();
        print(
            '   - Invitation ID: ${doc.id}, Status: ${data['status']}, Store: ${data['storeId']}');
      }

      // ✅ SADECE accepted invitations için kontrol (Senaryoda belirtildiği gibi)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('store_invitations')
          .where('email', isEqualTo: email)
          .where('status',
              whereIn: ['accepted', 'pending']) // ✅ ACCEPTED VE PENDING!
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final invitation = querySnapshot.docs.first.data();
        final status = invitation['status'];
        print(
            '✅ Invitation found for: $email - Status: $status - Store: ${invitation['storeId']}');
        return invitation;
      }

      print('🟡 No accepted invitation found for: $email');
      return null;
    } catch (e) {
      print('❌ Invitation check error: $e');
      // Hata durumunda null döndür - Normal kayıt devam etsin
      return null;
    }
  }

  // Login.md SENARYO A: Davetli kullanıcı kayıt işlemi
  Future<void> _handleInvitedUserRegistration(
      String email,
      String password,
      String name,
      String phone,
      Map<String, dynamic> invitation,
      UserCredential userCredential) async {
    try {
      print('🔵 Starting invited user registration for: $email');

      final storeId = invitation['storeId'];
      final role = invitation['role'] ?? 'staff';

      // Kullanıcı zaten authenticated
      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed - null user');
      }

      final userId = user.uid;
      print(
          '✅ User authenticated with UID: $userId - Will join store: $storeId');

      // CRITICAL: Clear store cache first for invited users
      await StoreSelectionService.instance.clearCache();
      print('🗑️ Store cache cleared for invited user');

      print('🔵 Saving user data to existing store: $storeId...');
      // 2. User bilgilerini DAVET EDİLEN STORE ID ile kaydet
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
        'storeId': storeId, // ← DAVET EDİLEN STORE ID (değişmeyecek!)
        'storeName': 'Davet Edildiğim Mağaza', // Geçici isim
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      print('✅ User document created with storeId: $storeId');

      // CRITICAL: Set correct store AFTER user document is created
      await StoreSelectionService.instance
          .setCurrentStore(storeId, 'Davet Edildiğim Mağaza');
      print('✅ Davetli kullanıcı için doğru store ID ayarlandı: $storeId');

      print('🔵 Adding user to existing store members...');
      // 3. Mevcut mağazaya üye olarak ekle (YENİ STORE OLUŞTURMA!)
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

      print('🔵 Updating invitation status to accepted...');
      // 4. ✅ Davet durumunu 'accepted' yap ve kullanıcı ID'yi ekle - OWNER KAYDI OLUŞTURMA!
      try {
        final invitationQuery = await FirebaseFirestore.instance
            .collection('store_invitations')
            .where('email', isEqualTo: email)
            .where('storeId', isEqualTo: storeId)
            .where('status', isEqualTo: 'accepted')
            .limit(1)
            .get();

        if (invitationQuery.docs.isNotEmpty) {
          final invitationDoc = invitationQuery.docs.first;
          await invitationDoc.reference.update({
            'userId': userId, // Kullanıcı ID'yi ekle
            'respondedAt': FieldValue.serverTimestamp(),
            'lastActivity': FieldValue.serverTimestamp(),
            'joinedAt': FieldValue.serverTimestamp(), // Katılma tarihini ekle
          });
          print('✅ Existing invitation updated with userId: $userId');
        } else {
          // Eğer accepted invitation bulunamazsa, pending olanı bul ve güncelle
          final pendingQuery = await FirebaseFirestore.instance
              .collection('store_invitations')
              .where('email', isEqualTo: email)
              .where('storeId', isEqualTo: storeId)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

          if (pendingQuery.docs.isNotEmpty) {
            final invitationDoc = pendingQuery.docs.first;
            await invitationDoc.reference.update({
              'userId': userId,
              'status': 'accepted',
              'respondedAt': FieldValue.serverTimestamp(),
              'lastActivity': FieldValue.serverTimestamp(),
              'joinedAt': FieldValue.serverTimestamp(),
            });
            print(
                '✅ Pending invitation updated to accepted with userId: $userId');
          }
        }
      } catch (invitationError) {
        print('⚠️ Could not update invitation: $invitationError');
        // Devam et - kullanıcı kayıdı başarılı
      }

      // CRITICAL: Davet edilen kullanıcı için ASLA owner kaydı oluşturma!
      print('🔍 Cleaning up any duplicate owner records for invited user...');
      try {
        // Davet edilen kullanıcı için yanlış owner kayıtlarını temizle
        final duplicateOwnerQuery = await FirebaseFirestore.instance
            .collection('store_invitations')
            .where('email', isEqualTo: email)
            .where('storeId', isEqualTo: storeId)
            .where('status', isEqualTo: 'owner')
            .get();

        for (var doc in duplicateOwnerQuery.docs) {
          await doc.reference.delete();
          print('🗑️ Deleted duplicate owner record for: $email');
        }

        if (duplicateOwnerQuery.docs.isNotEmpty) {
          print(
              '✅ Cleaned up ${duplicateOwnerQuery.docs.length} duplicate owner records');
        }

        // Aynı şekilde yanlış user activity kayıtlarını da temizle
        final wrongUserActivityQuery = await FirebaseFirestore.instance
            .collection('user_activity')
            .where('email', isEqualTo: email)
            .where('storeId', isEqualTo: storeId)
            .where('userId',
                isNotEqualTo: userId) // Yanlış userId'ye sahip kayıtlar
            .get();

        for (var doc in wrongUserActivityQuery.docs) {
          await doc.reference.delete();
          print('🗑️ Deleted wrong user activity record for: $email');
        }
      } catch (cleanupError) {
        print('⚠️ Error cleaning duplicate owner records: $cleanupError');
      }

      print('✅ Invited user registration completed successfully');

      // 4. Provider'ları güncelle ve yönlendir
      if (mounted) {
        print(
            '🔵 Davetli kullanici mevcut magazaya katildi - Dashboard\'a yonlendiriliyor...');
        // 5. Direkt dashboard'a git - Mağaza kurma sayfasına GİTME!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );

        _showSuccess('Hos geldiniz! Davet edildiginiz magazaya katildiniz.');
      }
    } catch (e) {
      print('❌ Invited user registration error: $e');
      throw e; // Re-throw to be caught by parent function
    }
  }

  // Login.md SENARYO B: Normal kullanıcı kayıt işlemi
  Future<void> _handleNormalUserRegistration(String email, String password,
      String name, String phone, UserCredential userCredential) async {
    try {
      print('🔵 Starting normal user registration for: $email');

      // Kullanıcı zaten authenticated
      final user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed - null user');
      }

      print('✅ Normal user created with UID: ${user.uid}');
      final userId = user.uid;
      final storeId = 'store_$userId'; // YENİ mağaza ID'si

      // CRITICAL: Initialize store selection with proper cache clearing for new users
      await StoreSelectionService.instance.initializeAfterLogin();

      print('🔵 Saving normal user data to Firestore...');
      // 2. User bilgilerini kaydet (Senaryo B formatında)
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'name': name,
        'phone': phone,
        'role': 'owner',
        'storeId': storeId, // ← YENİ mağaza ID'si: store_userId
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      print('🔵 Creating new store...');
      // 3. YENİ mağaza oluştur (Senaryo B formatında)
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set({
        'ownerId': userId,
        'name': '', // Boş - kullanıcı dolduracak
        'address': '', // Boş - kullanıcı dolduracak
        'phone': '', // Boş - kullanıcı dolduracak
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('🔵 Adding owner to store members...');
      // 4. Kendini mağaza sahibi olarak ekle (Senaryo B formatında)
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

      print('🔵 Adding owner to store_invitations for team management...');
      // 5. store_invitations'a da owner kaydı ekle (takım yönetimi için)
      await FirebaseFirestore.instance.collection('store_invitations').add({
        'email': email,
        'name': name,
        'userId': userId,
        'storeId': storeId,
        'role': 'owner',
        'status': 'owner',
        'invitedAt': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
        'invitedBy': userId, // Owner invites themselves
        'permissions': [
          'read',
          'write',
          'delete',
          'admin',
          'invite',
          'manage_users'
        ],
        'emailSent': false,
        'adminApprovalRequired': false,
        'isActive': true,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      print('✅ Normal user registration completed successfully');

      // 5. Yönlendir
      if (mounted) {
        print('🔵 Navigating to store setup...');
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

      // CRITICAL: Initialize store selection with proper cache clearing
      await StoreSelectionService.instance.initializeAfterLogin();

      // ✅ Beni hatırla özelliği
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_email', email);
        print('💾 User credentials saved for auto-login');
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remember_me');
        await prefs.remove('saved_email');
        print('🗑️ User credentials cleared');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
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
                            minHeight: 380,
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.65,
                          ),
                          padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),

          // ✅ Beni Hatırla Checkbox
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: const Color(0xFF2A5298),
              ),
              const Text(
                'Beni Hatırla',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),

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
