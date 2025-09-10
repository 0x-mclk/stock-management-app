import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/invitation_service.dart';
import 'store_setup_screen.dart';
import 'main_screen.dart';

class NewRegistrationScreen extends StatefulWidget {
  const NewRegistrationScreen({super.key});

  @override
  State<NewRegistrationScreen> createState() => _NewRegistrationScreenState();
}

class _NewRegistrationScreenState extends State<NewRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // ADIM 3C: Email'e davet var mı kontrol et
      final invitation = await _checkInvitation(email);

      if (invitation != null) {
        // SENARYO A: Davetli kullanıcı
        await _handleInvitedUser(email, password, name, phone, invitation);
      } else {
        // SENARYO B: Normal kullanıcı (kendi mağazasını kuracak)
        await _handleNormalUser(email, password, name, phone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ADIM 3C: Davet kontrolü - Login.md'ye göre "accepted" status aranır
  Future<Map<String, dynamic>?> _checkInvitation(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('store_invitations')
          .where('email', isEqualTo: email)
          .where('status',
              whereIn: ['pending', 'accepted']) // ✅ Both status kontrolü
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Davet kontrolü hatası: $e');
      return null;
    }
  }

  // SENARYO A: Davetli kullanıcı işlemleri
  Future<void> _handleInvitedUser(String email, String password, String name,
      String phone, Map<String, dynamic> invitation) async {
    // 1. Firebase Authentication hesap oluştur
    final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userId = userCredential.user!.uid;
    final storeId = invitation['storeId'] as String;
    final role = invitation['role'] as String? ?? 'staff';

    // 2. User bilgilerini kaydet
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
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
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 4. Davet durumunu güncelle
    await FirebaseFirestore.instance
        .collection('store_invitations')
        .where('email', isEqualTo: email)
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        doc.reference.update({'status': 'joined', 'userId': userId});
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mağaza takımına başarıyla katıldınız!'),
          backgroundColor: Colors.green,
        ),
      );

      // 5. Dashboard'a git - artık mağaza sahibi ile birlikte çalışıyor
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    }
  }

  // SENARYO B: Normal kullanıcı işlemleri (yeni mağaza)
  Future<void> _handleNormalUser(
      String email, String password, String name, String phone) async {
    // 1. Firebase Authentication hesap oluştur
    final userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userId = userCredential.user!.uid;
    final storeId = 'store_$userId';

    // 2. User bilgilerini kaydet
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'email': email,
      'name': name,
      'phone': phone,
      'role': 'owner',
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
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
      'joinedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hesabınız oluşturuldu! Şimdi mağaza bilgilerinizi tamamlayın.'),
          backgroundColor: Colors.green,
        ),
      );

      // 5. Mağaza kurulum sayfasına git
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const StoreSetupScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo veya başlık alanı
              const Icon(
                Icons.store,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'StockPro\'ya Hoş Geldiniz',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kayıt olun ve stok yönetimine başlayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // Ad Soyad
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ad soyad gereklidir';
                  }
                  if (value.trim().length < 2) {
                    return 'Ad soyad en az 2 karakter olmalıdır';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Telefon
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Telefon numarası gereklidir';
                  }
                  if (value.trim().length < 10) {
                    return 'Geçerli bir telefon numarası girin';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // E-posta (ÖNEMLİ - Davet kontrolü için)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                  helperText: 'Davet aldıysanız aynı e-postayı kullanın',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'E-posta adresi gereklidir';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value.trim())) {
                    return 'Geçerli bir e-posta adresi girin';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Şifre
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_passwordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre gereklidir';
                  }
                  if (value.length < 6) {
                    return 'Şifre en az 6 karakter olmalıdır';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Şifre Tekrar
              TextFormField(
                controller: _passwordConfirmController,
                decoration: InputDecoration(
                  labelText: 'Şifre Tekrar',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_confirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _confirmPasswordVisible = !_confirmPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_confirmPasswordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre tekrarı gereklidir';
                  }
                  if (value != _passwordController.text) {
                    return 'Şifreler eşleşmiyor';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submitRegistration(),
              ),
              const SizedBox(height: 32),

              // Kayıt Ol Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'KAYIT OL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Bilgi kutusu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '📋 Nasıl çalışır?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '👤 Davet aldıysanız: Aynı e-posta ile kayıt olun, mevcut mağaza takımına katılırsınız.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '🏪 Yeni kullanıcısanız: Kendi mağazanızı kurup yönetmeye başlayın.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
