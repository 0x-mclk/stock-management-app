import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/multi_user_indicators_widget.dart';
import '../services/invitation_service.dart';
import '../services/store_selection_service.dart';
import '../models/invitation_model.dart';
import '../utils/role_display.dart';
import 'admin_approval_screen.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final TextEditingController _emailController = TextEditingController();
  UserRole _selectedRole = UserRole.staff; // Davet: manager veya staff
  bool _isLoading = false;
  String? _currentStoreId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Aynı store service kullanarak Store ID alın
      final storeSelectionService = StoreSelectionService.instance;
      final storeId = await storeSelectionService.getCurrentStoreId();


      setState(() {
        _currentUserId = currentUser.uid;
        _currentStoreId = storeId; // Service'den gelen Store ID kullan
      });
    } else {
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Lütfen email adresi girin', isError: true);
      return;
    }

    if (_currentStoreId == null || _currentUserId == null) {
      _showMessage('Kullanıcı bilgileri yüklenemedi', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final invitationId = await InvitationService.instance.sendInvitation(
        storeId: _currentStoreId!, // Dinamik store ID kullan
        email: _emailController.text.trim(),
        role: _selectedRole,
        invitedBy: _currentUserId!,
      );

      if (invitationId != null) {
        _showMessage(
            'Davet gönderildi! Admin onayından sonra kullanıcıya bildirim ulaşacak.');
        _emailController.clear();
        setState(() {});
      } else {
        _showMessage('Davet gönderilemedi. Tekrar deneyin.', isError: true);
      }
    } catch (e) {
      _showMessage('Hata: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı verisi yüklenene kadar loading göster
    if (_currentStoreId == null || _currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Takım Yönetimi'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takım Yönetimi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Admin Approval Button - Dinamik store ID kullan
          StreamBuilder<List<InvitationModel>>(
            stream: InvitationService.instance
                .getPendingApprovalsStream(_currentStoreId!),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.length ?? 0;

              return Stack(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminApprovalScreen(
                            storeId: _currentStoreId!,
                            storeName: 'Mağazam',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    tooltip: 'Admin Onayları',
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          pendingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Takım Durumu Bölümü
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.group,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Takım Durumu',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MultiUserIndicatorsWidget(
                      storeId: _currentStoreId!, // Dinamik store ID kullan
                      currentUserId: _currentUserId!, // Dinamik user ID kullan
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Yeni Üye Davet Bölümü
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_add,
                          color: Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Yeni Üye Davet Et',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Email Input
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Adresi',
                        hintText: 'ornek@email.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 16),

                    // Rol Seçimi
                    const Text(
                      'Rol Seçin:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      children: RoleDisplay.invitableRoles.map((role) {
                        return ChoiceChip(
                          label: Text(RoleDisplay.label(role)),
                          selected: _selectedRole == role,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedRole = role);
                            }
                          },
                          selectedColor:
                              RoleDisplay.color(role).withValues(alpha: 0.3),
                          backgroundColor: Colors.grey[200],
                          avatar: Icon(
                            RoleDisplay.icon(role),
                            size: 16,
                            color: RoleDisplay.color(role),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      RoleDisplay.inviteDescription(_selectedRole),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),

                    const SizedBox(height: 16),

                    // Davet Gönder Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendInvitation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Davet Gönder',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Rol Açıklamaları
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Rol Açıklamaları',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTierDescription(
                      title: 'Yönetici',
                      description: RoleDisplay.tierDescriptionYonetici(),
                      color: RoleDisplay.color(UserRole.manager),
                      icon: RoleDisplay.icon(UserRole.manager),
                    ),
                    _buildTierDescription(
                      title: 'Çalışan',
                      description: RoleDisplay.tierDescriptionCalisan(),
                      color: RoleDisplay.color(UserRole.staff),
                      icon: RoleDisplay.icon(UserRole.staff),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierDescription({
    required String title,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
