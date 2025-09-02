import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/firebase_auth_service.dart';
import '../providers/product_provider.dart';

class FirestoreTestPage extends StatefulWidget {
  const FirestoreTestPage({super.key});

  @override
  State<FirestoreTestPage> createState() => _FirestoreTestPageState();
}

class _FirestoreTestPageState extends State<FirestoreTestPage> {
  final FirestoreService _firestoreService = FirestoreService.instance;
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  Map<String, dynamic>? currentUserData;
  bool isLoading = false;
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Kullanıcı verisi yükleniyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userData = await _firestoreService.getUser(currentUser.uid);
        setState(() {
          currentUserData = userData;
          statusMessage = userData != null
              ? '✅ Kullanıcı verisi başarıyla yüklendi'
              : '⚠️ Firestore\'da kullanıcı verisi bulunamadı';
        });
      } else {
        setState(() {
          statusMessage = '❌ Kimlik doğrulaması yapılmamış';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createUserInFirestore() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Firestore\'da kullanıcı oluşturuluyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        final success = await _firestoreService.createUser(
          userId: currentUser.uid,
          email: currentUser.email ?? 'test@example.com',
          name: currentUser.displayName ?? 'Test User',
          phone: '',
          subscriptionMode: 'basic',
          settings: {
            'theme': 'light',
            'language': 'tr',
            'notifications': true,
          },
        );

        if (success) {
          setState(() {
            statusMessage = '✅ Kullanıcı Firestore\'da başarıyla oluşturuldu!';
          });
          _loadCurrentUser(); // Reload to show updated data
        } else {
          setState(() {
            statusMessage = '❌ Kullanıcı oluşturma başarısız';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateUserLastLogin() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Son giriş zamanı güncelleniyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        final success =
            await _firestoreService.updateUserLastLogin(currentUser.uid);

        if (success) {
          setState(() {
            statusMessage = '✅ Son giriş zamanı güncellendi!';
          });
          _loadCurrentUser(); // Reload to show updated data
        } else {
          setState(() {
            statusMessage = '❌ Güncelleme başarısız';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createStoreInFirestore() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Firestore\'da store oluşturuluyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        final storeId = 'store_${DateTime.now().millisecondsSinceEpoch}';
        final success = await _firestoreService.createStore(
          storeId: storeId,
          name: 'Test Store',
          ownerId: currentUser.uid,
          ownerEmail: currentUser.email ?? 'test@store.com',
          ownerName: currentUser.displayName ?? 'Test User',
          address: 'Test Address',
          city: 'İstanbul',
          phone: '+90 555 123 4567',
          email: currentUser.email ?? 'test@store.com',
          taxNumber: '1234567890',
          settings: {
            'currency': 'TL',
            'taxRate': 18,
            'autoBackup': true,
            'notifications': {
              'lowStock': true,
              'newSale': true,
            },
          },
        );

        if (success) {
          setState(() {
            statusMessage =
                '✅ Store Firestore\'da başarıyla oluşturuldu! ID: $storeId';
          });
        } else {
          setState(() {
            statusMessage = '❌ Store oluşturma başarısız';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getUserStores() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Kullanıcı store\'ları yükleniyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        final stores = await _firestoreService.getUserStores(currentUser.uid);

        if (stores.isNotEmpty) {
          setState(() {
            statusMessage =
                '✅ ${stores.length} adet store bulundu:\n${stores.map((store) => '• ${store['name']} (${store['id']})').join('\n')}';
          });
        } else {
          setState(() {
            statusMessage = '⚠️ Hiç store bulunamadı';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Firestore bağlantısı test ediliyor...';
    });

    try {
      final success = await _firestoreService.testConnection();
      setState(() {
        statusMessage = success
            ? '✅ Firestore bağlantısı başarılı!'
            : '❌ Firestore bağlantısı başarısız';
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Bağlantı hatası: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 Firestore Test'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current User Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👤 Firebase Auth Bilgileri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (currentUser != null) ...[
                    Text('🆔 User ID: ${currentUser.uid}'),
                    Text('📧 Email: ${currentUser.email ?? 'N/A'}'),
                    Text('👤 Name: ${currentUser.displayName ?? 'N/A'}'),
                    Text('✅ Email Verified: ${currentUser.emailVerified}'),
                  ] else ...[
                    const Text('❌ Giriş yapılmamış'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Firestore Data
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔥 Firestore Kullanıcı Verisi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF388E3C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (currentUserData != null) ...[
                    Text('📧 Email: ${currentUserData!['email']}'),
                    Text('👤 Name: ${currentUserData!['name']}'),
                    Text('📱 Phone: ${currentUserData!['phone']}'),
                    Text('💎 Mode: ${currentUserData!['subscriptionMode']}'),
                    Text('✅ Active: ${currentUserData!['isActive']}'),
                    Text(
                        '📅 Created: ${currentUserData!['createdAt']?.toDate() ?? 'N/A'}'),
                    Text(
                        '🕐 Last Login: ${currentUserData!['lastLogin']?.toDate() ?? 'N/A'}'),
                  ] else ...[
                    const Text('⚠️ Firestore\'da veri bulunamadı'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Status Message
            if (statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusMessage.contains('✅')
                      ? Colors.green.shade100
                      : statusMessage.contains('❌')
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusMessage,
                  style: TextStyle(
                    color: statusMessage.contains('✅')
                        ? Colors.green.shade800
                        : statusMessage.contains('❌')
                            ? Colors.red.shade800
                            : Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Action Buttons
            if (currentUser != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _testConnection,
                  icon: const Icon(Icons.wifi_protected_setup),
                  label: const Text('Bağlantıyı Test Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // USER OPERATIONS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '👤 USER OPERATIONS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _createUserInFirestore,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Firestore\'da Kullanıcı Oluştur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _updateUserLastLogin,
                  icon: const Icon(Icons.update),
                  label: const Text('Son Giriş Zamanını Güncelle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // STORE OPERATIONS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Text(
                  '🏪 STORE OPERATIONS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF388E3C)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _createStoreInFirestore,
                  icon: const Icon(Icons.store),
                  label: const Text('Firestore\'da Store Oluştur'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _getUserStores,
                  icon: const Icon(Icons.list),
                  label: const Text('Kullanıcının Store\'larını Listele'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ===== STORE MEMBERS TEST SECTION =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Store Members Test',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _addOwnerToStore,
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Store Owner Ekle (İlk Adım)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _inviteUserToStore,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Kullanıcı Davet Et'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getStoreMembers,
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Store Üyelerini Listele'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getUserInvitations,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Kullanıcının Davetlerini Listele'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ===== PRODUCTS TEST SECTION =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Products Test',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _createTestProduct,
                        icon: const Icon(Icons.add_box),
                        label: const Text('Test Ürün Oluştur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getStoreProducts,
                        icon: const Icon(Icons.list),
                        label: const Text('Ürünleri Listele'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _updateProductStock,
                        icon: const Icon(Icons.edit),
                        label: const Text('Stok Güncelle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getLowStockProducts,
                        icon: const Icon(Icons.warning),
                        label: const Text('Düşük Stoklu Ürünler'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Migration İşlemleri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _checkMigrationStatus,
                        icon: const Icon(Icons.info),
                        label: const Text('Migration Durumu Kontrol Et'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            isLoading ? null : _migrateProductsToFirestore,
                        icon: const Icon(Icons.cloud_upload),
                        label:
                            const Text('SQLite Ürünlerini Firestore\'a Taşı'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ===== SALES TEST SECTION =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.point_of_sale,
                            color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Sales Test',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _createTestSale,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Test Satış Oluştur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getStoreSales,
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Satışları Listele'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getSalesStatistics,
                        icon: const Icon(Icons.analytics),
                        label: const Text('Satış İstatistikleri'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _getDailySalesTotal,
                        icon: const Icon(Icons.today),
                        label: const Text('Günlük Satış Toplamı'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _loadCurrentUser,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Verileri Yenile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===== STORE MEMBERS TEST METHODS =====

  Future<void> _addOwnerToStore() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Store owner ekleniyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      // Kullanıcının store'larını getir
      final stores = await _firestoreService.getUserStores(currentUser.uid);

      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı. Önce store oluşturun.';
        });
        return;
      }

      // İlk store'u kullan
      final storeId = stores.first['id'];

      // Store owner'ı members koleksiyonuna ekle
      final success = await _firestoreService.addStoreOwner(
        storeId: storeId,
        userId: currentUser.uid,
        email: currentUser.email ?? 'no-email',
        name: currentUser.displayName ?? 'Store Owner',
      );

      if (success) {
        setState(() {
          statusMessage = '✅ Store owner başarıyla eklendi! (Store: $storeId)';
        });
      } else {
        setState(() {
          statusMessage = '❌ Store owner ekleme başarısız';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _inviteUserToStore() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Kullanıcı davet ediliyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Önce kullanıcının store'larını al
        final stores = await _firestoreService.getUserStores(currentUser.uid);

        if (stores.isEmpty) {
          setState(() {
            statusMessage = '❌ Önce bir store oluşturmalısınız!';
          });
          return;
        }

        // İlk store'u kullan
        final storeId = stores.first['id'];

        // Test için demo kullanıcı davet et
        const inviteeEmail = 'demo@test.com';
        const role = 'staff';
        const permissions = ['read', 'write'];

        final success = await _firestoreService.inviteUserToStore(
          storeId: storeId,
          inviteeEmail: inviteeEmail,
          role: role,
          permissions: permissions,
          invitedByUserId: currentUser.uid,
          invitedByName: currentUser.displayName ?? 'Test User',
        );

        if (success) {
          setState(() {
            statusMessage =
                '✅ Kullanıcı başarıyla davet edildi: $inviteeEmail (Store: $storeId)';
          });
        } else {
          setState(() {
            statusMessage =
                '❌ Kullanıcı davet etme başarısız (zaten davet edilmiş olabilir)';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getStoreMembers() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Store üyeleri yükleniyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Önce kullanıcının store'larını al
        final stores = await _firestoreService.getUserStores(currentUser.uid);

        if (stores.isEmpty) {
          setState(() {
            statusMessage = '❌ Önce bir store oluşturmalısınız!';
          });
          return;
        }

        // İlk store'u kullan
        final storeId = stores.first['id'];
        final members = await _firestoreService.getStoreMembers(storeId);

        if (members.isNotEmpty) {
          setState(() {
            statusMessage =
                '✅ ${members.length} store üyesi bulundu (Store: $storeId):\n'
                '${members.map((m) => '  • ${m['name'] ?? m['email']} (${m['role']}) - ${m['status']}').join('\n')}';
          });
        } else {
          setState(() {
            statusMessage = '⚠️ Store üyesi bulunamadı (Store: $storeId)';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getUserInvitations() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Kullanıcı davetleri yükleniyor...';
    });

    try {
      final User? currentUser = _authService.currentUser;
      if (currentUser != null) {
        final invitations = await _firestoreService.getUserInvitations(
          currentUser.email ?? 'demo@test.com',
        );

        if (invitations.isNotEmpty) {
          setState(() {
            statusMessage = '✅ ${invitations.length} davet bulundu:\n'
                '${invitations.map((inv) => '  • ${inv['storeName']} - ${inv['role']} (${inv['status']})').join('\n')}';
          });
        } else {
          setState(() {
            statusMessage = '⚠️ Bekleyen davet bulunamadı';
          });
        }
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ===== PRODUCTS TEST METHODS =====

  Future<void> _createTestProduct() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Test ürün oluşturuluyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      // Kullanıcının store'larını getir
      final stores = await _firestoreService.getUserStores(currentUser.uid);

      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı. Önce store oluşturun.';
        });
        return;
      }

      // İlk store'u kullan
      final storeId = stores.first['id'];

      // Test ürün verisi
      final productId = 'product_${DateTime.now().millisecondsSinceEpoch}';
      final barcode = '${DateTime.now().millisecondsSinceEpoch}';

      final success = await _firestoreService.createProduct(
        storeId: storeId,
        productId: productId,
        barcode: barcode,
        name: 'Test Ürün ${DateTime.now().millisecondsSinceEpoch % 1000}',
        description: 'Firestore test için oluşturulan örnek ürün',
        salePrice: 25.50,
        purchasePrice: 15.00,
        stock: 100,
        minStock: 10,
        taxRate: 18.0,
        category: 'test',
        lastModifiedBy: currentUser.uid,
      );

      if (success) {
        setState(() {
          statusMessage =
              '✅ Test ürün başarıyla oluşturuldu! (Store: $storeId, Product: $productId)';
        });
      } else {
        setState(() {
          statusMessage = '❌ Ürün oluşturma başarısız';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getStoreProducts() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Ürünler yükleniyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      // Kullanıcının store'larını getir
      final stores = await _firestoreService.getUserStores(currentUser.uid);

      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı';
        });
        return;
      }

      // İlk store'un ürünlerini getir
      final storeId = stores.first['id'];
      final products = await _firestoreService.getStoreProducts(storeId);

      if (products.isNotEmpty) {
        final productList = products
            .map((p) =>
                '${p['name']} (Barkod: ${p['barcode']}, Stok: ${p['stock']}, Fiyat: ${p['salePrice']} TL)')
            .join('\\n');

        setState(() {
          statusMessage = '✅ ${products.length} ürün bulundu:\\n$productList';
        });
      } else {
        setState(() {
          statusMessage = '❌ Store\'da hiç ürün bulunamadı';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProductStock() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Ürün stoku güncelleniyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      // Kullanıcının store'larını getir
      final stores = await _firestoreService.getUserStores(currentUser.uid);

      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı';
        });
        return;
      }

      // İlk store'un ürünlerini getir
      final storeId = stores.first['id'];
      final products = await _firestoreService.getStoreProducts(storeId);

      if (products.isEmpty) {
        setState(() {
          statusMessage =
              '❌ Güncellenecek ürün bulunamadı. Önce test ürün oluşturun.';
        });
        return;
      }

      // İlk ürünün stokunu güncelle
      final product = products.first;
      final productId = product['id'];
      final currentStock = product['stock'] as int;
      final newStock = currentStock + 50; // 50 adet ekle

      final success = await _firestoreService.updateProductStock(
        storeId: storeId,
        productId: productId,
        newStock: newStock,
        lastModifiedBy: currentUser.uid,
        reason: 'Test stok güncellemesi',
      );

      if (success) {
        setState(() {
          statusMessage =
              '✅ Ürün stoku güncellendi! ${product['name']}: $currentStock → $newStock';
        });
      } else {
        setState(() {
          statusMessage = '❌ Stok güncelleme başarısız';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getLowStockProducts() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Düşük stoklu ürünler kontrol ediliyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      // Kullanıcının store'larını getir
      final stores = await _firestoreService.getUserStores(currentUser.uid);

      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı';
        });
        return;
      }

      // İlk store'un düşük stoklu ürünlerini getir
      final storeId = stores.first['id'];
      final lowStockProducts =
          await _firestoreService.getLowStockProducts(storeId);

      if (lowStockProducts.isNotEmpty) {
        final productList = lowStockProducts
            .map((p) =>
                '⚠️ ${p['name']} - Stok: ${p['stock']}/${p['minStock']} (Kritik!)')
            .join('\\n');

        setState(() {
          statusMessage =
              '🚨 ${lowStockProducts.length} ürün stok limitinde:\\n$productList';
        });
      } else {
        setState(() {
          statusMessage = '✅ Tüm ürünlerin stok seviyesi normal';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ===== MIGRATION TEST METHODS =====

  Future<void> _checkMigrationStatus() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Migration durumu kontrol ediliyor...';
    });

    try {
      // Get product provider from context
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final status = await productProvider.getMigrationStatus();

      final sqliteCount = status['sqliteCount'] ?? 0;
      final firestoreCount = status['firestoreCount'] ?? 0;
      final needsMigration = status['needsMigration'] ?? false;
      final hasStore = status['hasStore'] ?? false;
      final storeId = status['storeId'];

      String message = '📊 Migration Durumu:\\n';
      message += '💾 SQLite: $sqliteCount ürün\\n';
      message += '☁️ Firestore: $firestoreCount ürün\\n';
      message +=
          '🏪 Store: ${hasStore ? "Mevcut ($storeId)" : "Bulunamadı"}\\n';

      if (!hasStore) {
        message += '⚠️ Migration için önce store oluşturun!';
      } else if (needsMigration) {
        message +=
            '🚀 Migration gerekli: ${sqliteCount - firestoreCount} ürün taşınabilir';
      } else {
        message += '✅ Migration tamamlanmış!';
      }

      setState(() {
        statusMessage = message;
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Migration durumu kontrol hatası: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _migrateProductsToFirestore() async {
    setState(() {
      isLoading = true;
      statusMessage = 'SQLite ürünleri Firestore\'a taşınıyor...';
    });

    try {
      // Get product provider from context
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);

      final success = await productProvider.migrateProductsToFirestore();

      if (success) {
        setState(() {
          statusMessage =
              '🎉 Migration başarıyla tamamlandı!\\nÜrünler SQLite\'dan Firestore\'a taşındı.\\nAna uygulamada hybrid sync aktif!';
        });
      } else {
        setState(() {
          statusMessage =
              '❌ Migration başarısız oldu\\nDetaylar için terminal\'e bakın';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Migration hatası: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ===== SALES TEST METHODS =====

  Future<void> _createTestSale() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Test satış oluşturuluyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      // Get user's store
      final stores = await _firestoreService.getUserStores(currentUser.uid);
      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı. Önce store oluşturun.';
        });
        return;
      }

      final storeId = stores.first['id'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final saleId = 'sale_$timestamp';

      // Create test sale items
      final items = [
        {
          'productId': 'test_product_1',
          'productName': 'Test Ürün 1',
          'productBarcode': '123456789',
          'quantity': 2,
          'unitPrice': 15.50,
          'totalPrice': 31.00,
        },
        {
          'productId': 'test_product_2',
          'productName': 'Test Ürün 2',
          'productBarcode': '987654321',
          'quantity': 1,
          'unitPrice': 25.75,
          'totalPrice': 25.75,
        },
      ];

      const totalAmount = 56.75;
      const discount = 2.75;
      final finalAmount = totalAmount - discount;

      final success = await _firestoreService.createSale(
        storeId: storeId,
        saleId: saleId,
        userId: currentUser.uid,
        totalAmount: totalAmount,
        discount: discount,
        finalAmount: finalAmount,
        paymentMethod: 'cash',
        items: items,
        cashierName:
            currentUser.displayName ?? currentUser.email ?? 'Test Cashier',
        notes: 'Firestore test satışı',
      );

      if (success) {
        setState(() {
          statusMessage =
              '✅ Test satış başarıyla oluşturuldu!\\nSale ID: $saleId\\nToplam: ₺$finalAmount';
        });
      } else {
        setState(() {
          statusMessage = '❌ Test satış oluşturulamadı';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getStoreSales() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Satışlar getiriliyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      final stores = await _firestoreService.getUserStores(currentUser.uid);
      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı';
        });
        return;
      }

      final storeId = stores.first['id'];
      final sales = await _firestoreService.getStoreSales(storeId, limit: 10);

      if (sales.isNotEmpty) {
        String salesList = '';
        for (int i = 0; i < sales.length; i++) {
          final sale = sales[i];
          final createdAt = sale['createdAt']?.toDate();
          final finalAmount = sale['finalAmount'];
          salesList +=
              '${i + 1}. ₺$finalAmount - ${createdAt?.toString().substring(0, 19)}\\n';
        }

        setState(() {
          statusMessage = '✅ ${sales.length} satış bulundu:\\n\\n$salesList';
        });
      } else {
        setState(() {
          statusMessage = '📭 Henüz satış kaydı yok\\nTest satış oluşturun';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getSalesStatistics() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Satış istatistikleri hesaplanıyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      final stores = await _firestoreService.getUserStores(currentUser.uid);
      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı';
        });
        return;
      }

      final storeId = stores.first['id'];
      final endDate = DateTime.now();
      final startDate =
          endDate.subtract(const Duration(days: 30)); // Son 30 gün

      final stats = await _firestoreService.getSalesStatistics(
        storeId: storeId,
        startDate: startDate,
        endDate: endDate,
      );

      if (stats.isNotEmpty) {
        final totalRevenue = stats['totalRevenue'] ?? 0.0;
        final totalTransactions = stats['totalTransactions'] ?? 0;
        final averageTransaction = stats['averageTransaction'] ?? 0.0;
        final totalDiscount = stats['totalDiscount'] ?? 0.0;

        setState(() {
          statusMessage = '📊 Son 30 Gün İstatistikleri:\\n\\n'
              '💰 Toplam Gelir: ₺${totalRevenue.toStringAsFixed(2)}\\n'
              '🛒 İşlem Sayısı: $totalTransactions\\n'
              '📈 Ortalama İşlem: ₺${averageTransaction.toStringAsFixed(2)}\\n'
              '🎯 Toplam İndirim: ₺${totalDiscount.toStringAsFixed(2)}';
        });
      } else {
        setState(() {
          statusMessage = '📊 İstatistik verisi bulunamadı';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getDailySalesTotal() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Günlük satış toplamı hesaplanıyor...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          statusMessage = '❌ Kullanıcı oturum açmamış';
        });
        return;
      }

      final stores = await _firestoreService.getUserStores(currentUser.uid);
      if (stores.isEmpty) {
        setState(() {
          statusMessage = '❌ Store bulunamadı';
        });
        return;
      }

      final storeId = stores.first['id'];
      final today = DateTime.now();
      final total = await _firestoreService.getDailySalesTotal(storeId, today);

      setState(() {
        statusMessage = '📅 Bugünün Satış Toplamı:\\n\\n'
            '💰 ₺${total.toStringAsFixed(2)}\\n\\n'
            '📆 ${today.day}/${today.month}/${today.year}';
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Hata: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}




