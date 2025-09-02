import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../models/user_mode.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _storeNameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF1976D2),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Modern Header
                  _buildModernHeader(),

                  const SizedBox(height: 40),

                  // Register Card
                  _buildRegisterCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          // Logo Container with modern shadow
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.store_rounded,
              size: 50,
              color: Color(0xFF1976D2),
            ),
          ),

          const SizedBox(height: 30),

          // Welcome Text
          const Text(
            'Hesap Oluştur',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'StokPro ile stok takibinizi profesyonelleştirin',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            _buildModernRegisterForm(),
            const SizedBox(height: 24),
            _buildModernTermsCheckbox(),
            const SizedBox(height: 32),
            _buildModernRegisterButton(),
            const SizedBox(height: 24),
            _buildModernLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name Field
          _buildModernTextField(
            controller: _nameController,
            label: 'Ad Soyad',
            hint: 'Adınızı ve soyadınızı girin',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ad soyad gerekli';
              }
              if (value.trim().length < 2) {
                return 'Ad soyad en az 2 karakter olmalı';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Store Name Field
          _buildModernTextField(
            controller: _storeNameController,
            label: 'Mağaza/İşletme Adı',
            hint: 'İşletmenizin adını girin',
            icon: Icons.store_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Mağaza adı gerekli';
              }
              if (value.trim().length < 2) {
                return 'Mağaza adı en az 2 karakter olmalı';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Email Field
          _buildModernTextField(
            controller: _emailController,
            label: 'E-posta',
            hint: 'ornek@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'E-posta gerekli';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Geçerli bir e-posta adresi girin';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Password Field
          _buildModernTextField(
            controller: _passwordController,
            label: 'Şifre',
            hint: 'En az 6 karakter',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
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

          const SizedBox(height: 20),

          // Confirm Password Field
          _buildModernTextField(
            controller: _confirmPasswordController,
            label: 'Şifre Tekrar',
            hint: 'Şifrenizi tekrar girin',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şifre tekrar gerekli';
              }
              if (value != _passwordController.text) {
                return 'Şifreler eşleşmiyor';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: Colors.grey.shade600,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      validator: validator,
    );
  }

  Widget _buildModernTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) => setState(() => _acceptTerms = value ?? false),
          activeColor: const Color(0xFF1976D2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptTerms = !_acceptTerms),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                children: const [
                  TextSpan(text: 'Kullanım koşullarını ve '),
                  TextSpan(
                    text: 'gizlilik politikasını',
                    style: TextStyle(
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' kabul ediyorum.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading || !_acceptTerms ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Hesap Oluştur',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildModernLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Zaten hesabın var mı? ',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pushReplacementNamed('/login');
          },
          child: const Text(
            'Giriş Yap',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();

      // TRY FIREBASE FIRST
      final firebaseResult =
          await FirebaseAuthService.instance.registerWithEmailPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        storeName: _storeNameController.text.trim(),
        mode: UserMode.basic,
      );

      if (firebaseResult.success) {
        print('Firebase registration successful!');

        // Also register with local auth
        await AuthService.instance.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          storeName: _storeNameController.text.trim(),
        );

        if (mounted) {
          HapticFeedback.selectionClick();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Hesabınız Firebase ve local olarak başarıyla oluşturuldu!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to dashboard
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          );
        }
      } else {
        // Firebase failed, try local only
        print('Firebase registration failed: ${firebaseResult.message}');
        await _tryLocalRegister();
      }
    } catch (e) {
      print('Firebase registration error: $e');
      // Firebase error, try local
      await _tryLocalRegister();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tryLocalRegister() async {
    try {
      final result = await AuthService.instance.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        storeName: _storeNameController.text.trim(),
      );

      if (result.success) {
        if (mounted) {
          HapticFeedback.selectionClick();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hesabınız başarıyla oluşturuldu!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to dashboard
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          HapticFeedback.heavyImpact();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Kayıt başarısız'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
