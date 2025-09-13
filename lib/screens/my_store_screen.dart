import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/store_selection_service.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({super.key});

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  // Kullanıcı bilgileri
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _storeId = '';
  String _storeName = ''; // Mağaza adı için yeni alan
  DateTime? _createdAt;
  DateTime? _lastLogin;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🔥🔥🔥 MY STORE SCREEN BAŞLATILDI!');
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    print('🔥🔥🔥 MAĞAZAM BİLGİLERİ YÜKLENİYOR - BAŞLADI!');

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('🔥 Current user: ${currentUser.email}');

        // CRITICAL: Doğru store ID'yi al (davet edilen kullanıcılar için önemli)
        _storeId = await StoreSelectionService.instance.getCurrentStoreId();
        _storeName = await StoreSelectionService.instance.getCurrentStoreName();
        _userEmail = currentUser.email ?? '';
        _lastLogin = currentUser.metadata.lastSignInTime;

        print('🏪 Store ID: $_storeId');
        print('🏪 Store Name: $_storeName');

        // User activity koleksiyonundan da mağaza adını kontrol et
        String userActivityStoreName = '';
        try {
          final userActivityDoc = await FirebaseFirestore.instance
              .collection('user_activity')
              .doc('${_storeId}_${currentUser.uid}')
              .get();
          if (userActivityDoc.exists) {
            userActivityStoreName = userActivityDoc.data()?['storeName'] ?? '';
            print(
                '📊 User Activity\'den alınan mağaza adı: $userActivityStoreName');
          } else {
            print('⚠️ User activity belgesi mevcut değil!');
          }
        } catch (e) {
          print('⚠️ User activity\'den mağaza adı alınamadı: $e');
        }

        // Eğer user activity\'de mağaza adı varsa onu kullan
        if (userActivityStoreName.isNotEmpty) {
          _storeName = userActivityStoreName;
          print('🏆 User Activity\'den mağaza adı kullanılıyor: $_storeName');
        }

        // Firestore'dan kullanıcı bilgilerini al
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userName = userData['name'] ?? '';
            _userPhone = userData['phone'] ?? '';
            _createdAt = userData['createdAt']?.toDate();
          });

          print('✅ Kullanıcı bilgileri yüklendi:');
          print('   Ad: $_userName');
          print('   Email: $_userEmail');
          print('   Store: $_storeName ($_storeId)');
        }
      }
    } catch (e) {
      print('❌ Mağaza bilgileri yüklenirken hata: $e');
      // Hata durumunda varsayılan değerler kullanılır
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: currentUser!.email!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Şifre sıfırlama e-postası gönderildi'),
              backgroundColor: Colors.green,
            ),
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağazam'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStoreInfoCard(),
                  const SizedBox(height: 16),
                  _buildProfileCard(),
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStoreInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mağaza Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Mağaza Adı', _storeName.isNotEmpty ? _storeName : 'Mağaza'),
            _buildInfoRow('Store ID', _storeId),
            if (_createdAt != null)
              _buildInfoRow('Açılış Tarihi', _formatDate(_createdAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Ad Soyad', _userName),
            _buildInfoRow('E-posta', _userEmail),
            _buildInfoRow('Telefon', _userPhone),
            if (_lastLogin != null)
              _buildInfoRow('Son Giriş', _formatDate(_lastLogin!)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hesap İşlemleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.lock_reset),
                label: const Text('Şifre Değiştir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
