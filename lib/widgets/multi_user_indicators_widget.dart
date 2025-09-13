import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/real_time_service.dart';
import '../services/invitation_service.dart';
import '../models/invitation_model.dart';

class MultiUserIndicatorsWidget extends StatefulWidget {
  final String storeId;
  final String currentUserId;

  const MultiUserIndicatorsWidget({
    Key? key,
    required this.storeId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<MultiUserIndicatorsWidget> createState() =>
      _MultiUserIndicatorsWidgetState();
}

class _MultiUserIndicatorsWidgetState extends State<MultiUserIndicatorsWidget> {
  final RealTimeService _realTimeService = RealTimeService.instance;
  final InvitationService _invitationService = InvitationService.instance;

  @override
  void initState() {
    super.initState();
    print(
        '🚀 MultiUserIndicatorsWidget initState - StoreID: ${widget.storeId}, UserID: ${widget.currentUserId}');
    _updateUserActivity();
  }

  void _updateUserActivity() async {
    // Mevcut kullanıcının aktivitesini güncelle
    await _realTimeService.updateUserActivity(
      storeId: widget.storeId,
      userId: widget.currentUserId,
    );

    // Mağaza sahibi kaydının var olduğundan emin ol
    await _ensureStoreOwnerExists();

    // Tüm store üyelerinin aktivite bilgilerini senkronize et
    await _synchronizeAllMembersActivity();
  }

  /// Mağaza sahibi kaydının var olduğundan emin ol
  Future<void> _ensureStoreOwnerExists() async {
    try {
      // Firebase Auth'dan mevcut kullanıcının gerçek email'ini al
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        print('❌ Mevcut kullanıcı bulunamadı veya email adresi yok');
        return;
      }

      final currentUserEmail = currentUser.email!;
      print('📧 Mevcut kullanıcı email: $currentUserEmail');
      print('🏪 Mevcut store ID: ${widget.storeId}');

      // Mağaza sahibi kaydını temizle ve doğruyu ekle
      await _invitationService.ensureStoreOwnerExistsWithCleanup(
        storeId: widget.storeId,
        userId: widget.currentUserId,
        email: currentUserEmail,
      );

      // User activity kayıtlarını da temizle
      await _realTimeService.cleanupIncorrectUserActivities(
        storeId: widget.storeId,
        correctUserId: widget.currentUserId,
        correctEmail: currentUserEmail,
      );
    } catch (e) {
      print('❌ Mağaza sahibi kaydı oluşturulamadı: $e');
    }
  }

  /// Tüm store üyelerinin aktivite bilgilerini senkronize et
  Future<void> _synchronizeAllMembersActivity() async {
    try {
      print('🔄 Store üyelerini almaya başlıyor: StoreID = ${widget.storeId}');

      // Store'daki tüm aktif üyeleri al
      final members =
          await _invitationService.getMembersStream(widget.storeId).first;

      print('👥 Alınan üye sayısı: ${members.length}');
      for (final member in members) {
        print(
            '👤 Üye: ${member.email}, Status: ${member.status}, UserID: ${member.userId}');
      }

      // Eksik userId alanlarını güncelle
      await _updateMissingUserIds(members);

      // Aktif üyeleri filtrele
      final activeMembers = members
          .where((member) =>
              member.status == InvitationStatus.owner ||
              member.status == InvitationStatus.accepted)
          .toList();

      print('🟢 Aktif üye sayısı: ${activeMembers.length}/${members.length}');

      // Batch update için kullanıcı listesi hazırla
      final usersForBatchUpdate = activeMembers
          .where((member) => member.userId != null && member.userId!.isNotEmpty)
          .map((member) => {
                'userId': member.userId!,
                'email': member.email,
                'role': member.role.name,
              })
          .toList();

      print(
          '🔄 Batch update için hazırlanan kullanıcı sayısı: ${usersForBatchUpdate.length}');

      // Batch update kullanarak tüm üyelerin aktivitesini güncelle
      if (usersForBatchUpdate.isNotEmpty) {
        await _realTimeService.batchUpdateUserActivity(
          storeId: widget.storeId,
          users: usersForBatchUpdate,
        );
      }

      print(
          '🔄 Tüm store üyelerinin aktivite bilgileri senkronize edildi (${usersForBatchUpdate.length} üye)');
    } catch (e) {
      print('❌ Üye aktivite senkronizasyon hatası: $e');
    }
  }

  /// Eksik userId alanlarını güncelle
  Future<void> _updateMissingUserIds(List<InvitationModel> members) async {
    try {
      // User activity verilerini al
      final activityData =
          await _realTimeService.getUserActivityStream(widget.storeId).first;

      print('🔍 Activity verilerinde ${activityData.length} kullanıcı bulundu');

      for (final member in members) {
        // Eğer userId boşsa, email eşleştirmesi ile bulmaya çalış
        if (member.userId == null || member.userId!.isEmpty) {
          // E-mail bazlı eşleştirme deneme
          final matchingActivity = activityData.firstWhere(
            (activity) => activity['email'] == member.email,
            orElse: () => <String, dynamic>{},
          );

          if (matchingActivity.isNotEmpty && member.id != null) {
            final foundUserId = matchingActivity['userId'];
            print('🔄 ${member.email} için userId bulundu: $foundUserId');

            // Member kaydını güncelle
            await _invitationService.updateMemberUserId(
              memberId: member.id!,
              userId: foundUserId,
            );
          } else {
            print('⚠️ ${member.email} için activity kaydı bulunamadı');
          }
        }
      }
    } catch (e) {
      print('❌ UserId güncelleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔄 MultiUserIndicatorsWidget build called');
    return Column(
      children: [
        _buildOnlineUsers(),
        const SizedBox(height: 8),
        _buildMemberOverview(),
      ],
    );
  }

  Widget _buildOnlineUsers() {
    print('📊 Building online users stream for StoreID: ${widget.storeId}');

    // İki stream'i birleştir: user_activity ve store_invitations
    return StreamBuilder<List<InvitationModel>>(
      stream: _invitationService.getMembersStream(widget.storeId),
      builder: (context, membersSnapshot) {
        if (membersSnapshot.hasError) {
          print('❌ Members stream error: ${membersSnapshot.error}');
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Üye listesi hatası: ${membersSnapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        }

        if (!membersSnapshot.hasData) {
          print('⏳ Members data loading...');
          return Container(
            padding: const EdgeInsets.all(12),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final allMembers = membersSnapshot.data!;
        final activeMembers = allMembers
            .where((member) =>
                member.status == InvitationStatus.owner ||
                member.status == InvitationStatus.accepted)
            .toList();

        // Şimdi user_activity stream'ini al
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _realTimeService.getUserActivityStream(widget.storeId),
          builder: (context, activitySnapshot) {
            print(
                '📊 Activity Stream state: ${activitySnapshot.connectionState}, hasData: ${activitySnapshot.hasData}, error: ${activitySnapshot.error}');

            if (activitySnapshot.hasError) {
              print('❌ Activity Stream error: ${activitySnapshot.error}');
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Aktivite stream hatası: ${activitySnapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              );
            }

            // Activity verisi yok ise bile üyeleri göster
            final activityData = activitySnapshot.data ?? [];

            // Üyeleri aktivite verileri ile birleştir
            List<Map<String, dynamic>> combinedUsers = [];

            for (final member in activeMembers) {
              // userId varsa direkt eşleştir, yoksa email'dan türet
              String? userId = member.userId;

              // UserId yoksa, activity verilerinden email ile eşleştirmeye çalış
              if (userId == null || userId.isEmpty) {
                // Activity verilerinden bu email'e sahip kullanıcıyı bul
                final matchingActivity = activityData.firstWhere(
                  (activity) => activity['email'] == member.email,
                  orElse: () => <String, dynamic>{},
                );
                userId = matchingActivity['userId'];

                // Hala userId bulunamadıysa, email'den unique bir ID türet
                if (userId == null || userId.isEmpty) {
                  print(
                      '⚠️ Üye ${member.email} için userId bulunamadı, varsayılan değer kullanılıyor');
                  // Email'den basit bir hash oluştur
                  userId = member.email.hashCode.abs().toString();
                }
              }

              // Bu üyenin aktivite verisini bul (userId veya email ile)
              final activity = activityData.firstWhere(
                (activity) =>
                    activity['userId'] == userId ||
                    activity['email'] == member.email,
                orElse: () => <String, dynamic>{},
              );

              // Birleştirilmiş veri oluştur
              final combinedData = {
                'userId': userId,
                'email': member.email,
                'role': member.role.name,
                'storeId': widget.storeId,
                'lastActivity': activity['lastActivity'] ?? member.lastActivity,
                'isActive': activity['isActive'] ?? true,
                'memberStatus': member.status.name,
                'hasRealActivity':
                    activity.isNotEmpty, // Gerçek aktivite verisi var mı?
              };

              print(
                  '👤 Combined user: ${member.email}, userId: $userId, hasActivity: ${activity.isNotEmpty}');
              combinedUsers.add(combinedData);
            }

            print(
                '👥 Combined users data: ${combinedUsers.length} üye (${activeMembers.length} aktif üyeden)');

            // Online kullanıcıları filtrele
            final onlineUsers = combinedUsers.where((user) {
              final lastActivity = user['lastActivity'];
              final hasRealActivity = user['hasRealActivity'] ?? false;

              // Gerçek aktivite verisi yoksa, üyeyi varsayılan olarak çevrimiçi say
              if (!hasRealActivity) {
                print(
                    '🟡 ${user['email']} - gerçek aktivite verisi yok, varsayılan olarak çevrimiçi');
                return true;
              }

              if (lastActivity == null) {
                print('🔴 ${user['email']} - lastActivity null');
                return false;
              }

              DateTime lastActiveTime;
              if (lastActivity is DateTime) {
                lastActiveTime = lastActivity;
              } else {
                try {
                  lastActiveTime = lastActivity.toDate();
                } catch (e) {
                  print('🔴 ${user['email']} - lastActivity format hatası: $e');
                  return false;
                }
              }

              final now = DateTime.now();
              final difference = now.difference(lastActiveTime);
              final isOnline =
                  difference.inMinutes < 5; // 5 dakika içinde aktif

              print(
                  '👤 ${user['email']} - Son aktivite: ${difference.inMinutes} dakika önce, Çevrimiçi: $isOnline');
              return isOnline;
            }).toList();

            print(
                '🟢 Online users: ${onlineUsers.length}/${combinedUsers.length}');

            if (onlineUsers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Toplam ${combinedUsers.length} üye var, şu anda kimse çevrimiçi değil',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Çevrimiçi Takım (${onlineUsers.length}/${combinedUsers.length})',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: onlineUsers
                        .map((user) => _buildUserChip(user))
                        .toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserChip(Map<String, dynamic> user) {
    final email = user['email'] ?? '';
    final role = user['role'] ?? '';
    final username = email.contains('@') ? email.split('@')[0] : email;
    final isCurrentUser = user['userId'] == widget.currentUserId;

    Color chipColor;
    switch (role) {
      case 'owner':
        chipColor = Colors.purple;
        break;
      case 'manager':
        chipColor = Colors.blue;
        break;
      case 'staff':
        chipColor = Colors.green;
        break;
      case 'partner':
        chipColor = Colors.orange;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: chipColor.withValues(alpha: isCurrentUser ? 0.8 : 0.3),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isCurrentUser ? '$username (Sen)' : username,
            style: TextStyle(
              color: chipColor.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberOverview() {
    print('📊 Building member overview stream for StoreID: ${widget.storeId}');
    return StreamBuilder<List<InvitationModel>>(
      stream: _invitationService.getMembersStream(widget.storeId),
      builder: (context, snapshot) {
        print(
            '📊 Member stream state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}');

        if (snapshot.hasError) {
          print('❌ Member stream error: ${snapshot.error}');
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Üye listesi hatası: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        }

        if (!snapshot.hasData) {
          print('⏳ Member data loading...');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final members = snapshot.data!;
        final activeMembers = members
            .where((m) =>
                m.status == InvitationStatus.owner ||
                m.status == InvitationStatus.accepted)
            .toList();
        final pendingInvites = members
            .where((m) =>
                m.status == InvitationStatus.invited ||
                m.status == InvitationStatus.pending)
            .toList();

        return Column(
          children: [
            // Genel özet
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Takım Özeti',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Aktif',
                        activeMembers.length.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                      _buildStatItem(
                        'Bekleyen',
                        pendingInvites.length.toString(),
                        Colors.orange,
                        Icons.schedule,
                      ),
                      _buildStatItem(
                        'Toplam',
                        members.length.toString(),
                        Colors.blue,
                        Icons.group,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Detaylı üye listesi
            if (activeMembers.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Aktif Takım Üyeleri (${activeMembers.length})',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...activeMembers.map((member) => _buildMemberTile(member)),
                  ],
                ),
              ),

            if (pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Bekleyen Davetler (${pendingInvites.length})',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...pendingInvites.map((member) => _buildMemberTile(member)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(InvitationModel member) {
    final isCurrentUser = member.userId == widget.currentUserId;
    final roleColor = _getRoleColor(member.role);
    final statusColor = _getStatusColor(member.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: roleColor.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              _getRoleIcon(member.role),
              color: roleColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Kullanıcı bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.email,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              isCurrentUser ? Colors.blue[700] : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Siz',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Rol badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getRoleDisplayName(member.role),
                        style: TextStyle(
                          fontSize: 11,
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Durum badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusDisplayName(member.status),
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Son aktivite (varsa)
                if (member.lastActivity != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Son aktivite: ${_formatLastActivity(member.lastActivity!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // Yardımcı metodlar
  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Colors.purple;
      case UserRole.manager:
        return Colors.blue;
      case UserRole.staff:
        return Colors.green;
      case UserRole.partner:
        return Colors.orange;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Icons.star;
      case UserRole.manager:
        return Icons.manage_accounts;
      case UserRole.staff:
        return Icons.person;
      case UserRole.partner:
        return Icons.handshake;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Sahip';
      case UserRole.manager:
        return 'Yönetici';
      case UserRole.staff:
        return 'Personel';
      case UserRole.partner:
        return 'Ortak';
    }
  }

  Color _getStatusColor(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.owner:
        return Colors.purple;
      case InvitationStatus.accepted:
        return Colors.green;
      case InvitationStatus.invited:
        return Colors.blue;
      case InvitationStatus.pending:
        return Colors.orange;
      case InvitationStatus.approved:
        return Colors.teal;
      case InvitationStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusDisplayName(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.owner:
        return 'Sahip';
      case InvitationStatus.accepted:
        return 'Aktif';
      case InvitationStatus.invited:
        return 'Davet Edildi';
      case InvitationStatus.pending:
        return 'Beklemede';
      case InvitationStatus.approved:
        return 'Onaylandı';
      case InvitationStatus.rejected:
        return 'Reddedildi';
    }
  }

  String _formatLastActivity(DateTime lastActivity) {
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}
