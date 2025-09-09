import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key});

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _completeStoreSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Kullanıcı oturum açmamış');

      final userId = user.uid;
      final storeId = 'store_$userId';

      // Mağaza bilgilerini güncelle
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'name': _storeNameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'setupCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mağaza kurulumu tamamlandı! Hoş geldiniz!'),
            backgroundColor: Colors.green,
          ),
        );

        // Dashboard'a yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza Kurulumu'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Geri butonunu kaldır
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hoş geldin mesajı
              const Icon(
                Icons.store_mall_directory,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Mağazanızı Kuralım!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mağaza bilgilerinizi doldurun ve stok yönetimine başlayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // Mağaza Adı
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Mağaza Adı',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                  helperText: 'Örn: Ahmet Bakkaliyesi, Özkan Market',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Mağaza adı gereklidir';
                  }
                  if (value.trim().length < 2) {
                    return 'Mağaza adı en az 2 karakter olmalıdır';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Adres
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Mağaza Adresi',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                  helperText: 'Tam adresinizi yazın',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Mağaza adresi gereklidir';
                  }
                  if (value.trim().length < 10) {
                    return 'Lütfen daha detaylı bir adres girin';
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
                  labelText: 'Mağaza Telefonu',
                  prefixIcon: Icon(Icons.phone_in_talk),
                  border: OutlineInputBorder(),
                  helperText: 'Müşterilerinizin arayabileceği telefon',
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
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _completeStoreSetup(),
              ),
              const SizedBox(height: 32),

              // Kurulumu Tamamla Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _completeStoreSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                        'KURULUMU TAMAMLA',
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '🎉 Tebrikler!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Kendi mağazanızın sahibi oldunuz. Bu bilgileri doldurduktan sonra:',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✅ Stok takibi yapabileceksiniz',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✅ Satış kayıtları tutabileceksiniz',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '✅ Takım arkadaşlarını davet edebileceksiniz',
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
