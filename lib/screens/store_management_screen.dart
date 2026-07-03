import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/store_selection_service.dart';
import '../services/real_time_service.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _taxNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // CRITICAL: Doğru store ID'sini al (davet edilen kullanıcılar için önemli)
      final storeId = await StoreSelectionService.instance.getCurrentStoreId();
      final storeName =
          await StoreSelectionService.instance.getCurrentStoreName();


      // StoreSelectionService cache durumunu kontrol et
      await StoreSelectionService.instance.initializeAfterLogin();
      final finalStoreId =
          await StoreSelectionService.instance.getCurrentStoreId();
      final finalStoreName =
          await StoreSelectionService.instance.getCurrentStoreName();

      // Firebase'den mağaza bilgilerini al
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(finalStoreId)
          .get();

      // YENI: User activity koleksiyonundan da mağaza adını kontrol et
      final currentUser = FirebaseAuth.instance.currentUser;
      String userActivityStoreName = '';
      if (currentUser != null) {
        try {
          final userActivityDoc = await FirebaseFirestore.instance
              .collection('user_activity')
              .doc('${finalStoreId}_${currentUser.uid}')
              .get();
          if (userActivityDoc.exists) {
            userActivityStoreName = userActivityDoc.data()?['storeName'] ?? '';
                '📊 User Activity\'den alınan mağaza adı: $userActivityStoreName');
          }
        } catch (e) {
        }
      }

      if (storeDoc.exists) {
        final storeData = storeDoc.data()!;


        // Mağaza adı seçimi: user activity > store document > cached name
        String displayStoreName = storeData['name'] ?? '';
        if (userActivityStoreName.isNotEmpty) {
          displayStoreName = userActivityStoreName;
              '🏆 User Activity\'den mağaza adı kullanılıyor: $displayStoreName');
        } else if (displayStoreName.isEmpty) {
          displayStoreName = finalStoreName;
        }

        // Form field'larını doldur
        _storeNameController.text = displayStoreName;
        _phoneController.text = storeData['phone'] ?? '';
        _addressController.text = storeData['address'] ?? '';
        _cityController.text = storeData['city'] ?? '';
        _postalCodeController.text = storeData['postalCode'] ?? '';
        _taxNumberController.text = storeData['taxNumber'] ?? '';
        _descriptionController.text = storeData['description'] ?? '';
        _emailController.text = storeData['email'] ?? '';

        // Mağaza sahibinin adını al
        final userName = await AuthService.instance.getUserName() ?? '';
        _ownerNameController.text = userName;

      } else {

        // Varsayılan değerler - user activity\'den alınan adı kullan
        String displayName = userActivityStoreName.isNotEmpty
            ? userActivityStoreName
            : finalStoreName;
        _storeNameController.text = displayName;
        final userName = await AuthService.instance.getUserName() ?? '';
        _ownerNameController.text = userName;

      }
    } catch (e) {

      // Fallback - eski metodu kullan
      final storeName = await AuthService.instance.getStoreName() ?? '';
      final userName = await AuthService.instance.getUserName() ?? '';

      _storeNameController.text = storeName;
      _ownerNameController.text = userName;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildModernAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildStoreProfileCard(),
                          const SizedBox(height: 20),
                          _buildInformationSection(),
                          const SizedBox(height: 20),
                          _buildContactSection(),
                          const SizedBox(height: 20),
                          _buildLocationSection(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Mağaza Yönetimi'),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.store,
              size: 80,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreProfileCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mağaza Profili',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _storeNameController,
              label: 'Mağaza Adı',
              icon: Icons.store,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _ownerNameController,
              label: 'Sahip Adı',
              icon: Icons.person,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mağaza Bilgileri',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Store ID'yi göster (salt okunur)
            FutureBuilder<String>(
              future: StoreSelectionService.instance.getCurrentStoreId(),
              builder: (context, snapshot) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mağaza ID',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              snapshot.hasData
                                  ? snapshot.data!
                                  : 'Yükleniyor...',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _taxNumberController,
              label: 'Vergi Numarası',
              icon: Icons.receipt,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Açıklama',
              icon: Icons.description,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İletişim Bilgileri',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Telefon',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'E-posta',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konum Bilgileri',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Adres',
              icon: Icons.location_on,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'Şehir',
                    icon: Icons.location_city,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _postalCodeController,
                    label: 'Posta Kodu',
                    icon: Icons.mail,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveStoreInfo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Bilgileri Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !_isEditing,
        fillColor: _isEditing ? null : Colors.grey.shade50,
      ),
    );
  }

  Future<void> _saveStoreInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      HapticFeedback.lightImpact();

      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 1500));

      // In a real app, you'd save to your backend/database
      // For demo, we'll save to SharedPreferences
      await AuthService.instance.updateStoreInfo(
        storeName: _storeNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
      );

      // You can extend this to save all fields to a more comprehensive store profile

      if (mounted) {
        HapticFeedback.selectionClick();

        setState(() {
          _isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mağaza bilgileri başarıyla güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bilgiler kaydedilirken hata oluştu: $e'),
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
}
