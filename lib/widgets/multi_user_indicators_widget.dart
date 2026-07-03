import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/real_time_service.dart';
import '../services/invitation_service.dart';
import '../models/invitation_model.dart';
import '../utils/role_display.dart';

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

class _MultiUserIndicatorsWidgetState
    extends State<MultiUserIndicatorsWidget> {
  final RealTimeService _realTimeService = RealTimeService.instance;
  final InvitationService _invitationService = InvitationService.instance;

  // Aktivite güncellemesini kısıtla — initState'de 1 kez çalışır
  bool _activityUpdated = false;

  @override
  void initState() {
    super.initState();
    _scheduleActivityUpdate();
  }

  void _scheduleActivityUpdate() {
    if (_activityUpdated) return;
    _activityUpdated = true;
    // İlk frame sonrasında arka planda çalıştır, UI'yı bloke etmesin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateUserActivity();
    });
  }

  Future<void> _updateUserActivity() async {
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .get();
      final storeData = storeDoc.data();
      final storeName = (storeData != null ? storeData['name'] : null) ?? 'Mağaza';

      await _realTimeService.updateUserActivity(
        storeId: widget.storeId,
        userId: widget.currentUserId,
        storeName: storeName,
      );

      await _ensureStoreOwnerExists();
      await _synchronizeAllMembersActivity();
    } catch (_) {}
  }

  Future<void> _ensureStoreOwnerExists() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) return;

      final currentUserEmail = currentUser.email!;
      final currentUserId = currentUser.uid;

      final isOwner =
          await _checkIfUserIsStoreOwner(widget.storeId, currentUserId);
      if (!isOwner) return;

      await _invitationService.ensureStoreOwnerExistsWithCleanup(
        storeId: widget.storeId,
        userId: widget.currentUserId,
        email: currentUserEmail,
      );
      await _ensureOwnerInMembersCollection(currentUserEmail, currentUserId);
      await _realTimeService.cleanupIncorrectUserActivities(
        storeId: widget.storeId,
        correctUserId: widget.currentUserId,
        correctEmail: currentUserEmail,
      );
    } catch (_) {}
  }

  Future<void> _ensureOwnerInMembersCollection(
      String email, String userId) async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('members')
          .doc(userId)
          .get();

      if (!memberDoc.exists) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final userName = currentUser?.displayName ?? email.split('@')[0];
        await FirebaseFirestore.instance
            .collection('stores')
            .doc(widget.storeId)
            .collection('members')
            .doc(userId)
            .set({
          'email': email,
          'name': userName,
          'role': 'owner',
          'status': 'owner',
          'userId': userId,
          'joinedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        });
      } else {
        final data = memberDoc.data()!;
        final updates = <String, dynamic>{};
        if (data['role'] != 'owner') updates['role'] = 'owner';
        if (data['status'] != 'owner') updates['status'] = 'owner';
        if (data['isActive'] != true) updates['isActive'] = true;
        if (data['userId'] != userId) updates['userId'] = userId;
        if (updates.isNotEmpty) await memberDoc.reference.update(updates);
      }
    } catch (_) {}
  }

  Future<void> _synchronizeAllMembersActivity() async {
    try {
      final members =
          await _invitationService.getMembersStream(widget.storeId).first;

      await _updateMissingUserIds(members);

      final activeMembers = members
          .where((m) =>
              m.status == InvitationStatus.owner ||
              m.status == InvitationStatus.accepted)
          .toList();

      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .get();
      final storeDocData = storeDoc.data();
      final storeName = (storeDocData != null ? storeDocData['name'] : null) ?? 'Mağaza';

      final usersForBatch = activeMembers
          .where((m) => m.userId != null && m.userId!.isNotEmpty)
          .map((m) => {
                'userId': m.userId!,
                'email': m.email,
                'role': m.role.name,
              })
          .toList();

      if (usersForBatch.isNotEmpty) {
        await _realTimeService.batchUpdateUserActivity(
          storeId: widget.storeId,
          users: usersForBatch,
          storeName: storeName,
        );
      }
    } catch (_) {}
  }

  Future<void> _updateMissingUserIds(List<InvitationModel> members) async {
    try {
      final activityData =
          await _realTimeService.getUserActivityStream(widget.storeId).first;

      for (final member in members) {
        if (member.userId == null || member.userId!.isEmpty) {
          final matchingActivity = activityData.firstWhere(
            (a) => a['email'] == member.email,
            orElse: () => <String, dynamic>{},
          );
          if (matchingActivity.isNotEmpty && member.id != null) {
            await _invitationService.updateMemberUserId(
              memberId: member.id!,
              userId: matchingActivity['userId'],
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<bool> _checkIfUserIsStoreOwner(
      String storeId, String userId) async {
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();
      if (!storeDoc.exists) return false;
      return storeDoc.data()!['ownerId'] == userId;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Build — print() YOK
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        children: [
          _buildOnlineUsers(),
          const SizedBox(height: 8),
          _buildMemberOverview(),
        ],
      ),
    );
  }

  Widget _buildOnlineUsers() {
    return StreamBuilder<List<InvitationModel>>(
      stream: _invitationService.getMembersStream(widget.storeId),
      builder: (context, membersSnapshot) {
        if (membersSnapshot.hasError) {
          return _errorBox('Üye listesi hatası');
        }
        if (!membersSnapshot.hasData) {
          return const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final activeMembers = membersSnapshot.data!
            .where((m) =>
                m.status == InvitationStatus.owner ||
                m.status == InvitationStatus.accepted)
            .toList();

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _realTimeService.getUserActivityStream(widget.storeId),
          builder: (context, activitySnapshot) {
            final activityData = activitySnapshot.data ?? [];
            final combinedUsers = _combineUsersWithActivity(
                activeMembers, activityData);
            final onlineUsers = _filterOnlineUsers(combinedUsers);

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
                      'Toplam ${combinedUsers.length} üye, şu an çevrimiçi yok',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12),
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
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3)),
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
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Çevrimiçi Takım '
                          '(${onlineUsers.length}/${combinedUsers.length})',
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
                        .map((u) => _buildUserChip(u))
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

  List<Map<String, dynamic>> _combineUsersWithActivity(
      List<InvitationModel> members,
      List<Map<String, dynamic>> activityData) {
    return members.map((member) {
      String? userId = member.userId;
      if (userId == null || userId.isEmpty) {
        final match = activityData.firstWhere(
          (a) => a['email'] == member.email,
          orElse: () => <String, dynamic>{},
        );
        userId = match['userId'] as String? ??
            member.email.hashCode.abs().toString();
      }

      final activity = activityData.firstWhere(
        (a) => a['userId'] == userId || a['email'] == member.email,
        orElse: () => <String, dynamic>{},
      );

      return {
        'userId': userId,
        'email': member.email,
        'role': member.role.name,
        'storeId': widget.storeId,
        'lastActivity': activity['lastActivity'] ?? member.lastActivity,
        'isActive': activity['isActive'] ?? true,
        'memberStatus': member.status.name,
        'hasRealActivity': activity.isNotEmpty,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterOnlineUsers(
      List<Map<String, dynamic>> users) {
    return users.where((user) {
      if (!(user['hasRealActivity'] as bool)) return true;
      final lastActivity = user['lastActivity'];
      if (lastActivity == null) return false;
      try {
        final DateTime lastActiveTime = lastActivity is DateTime
            ? lastActivity
            : lastActivity.toDate();
        return DateTime.now().difference(lastActiveTime).inMinutes < 5;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Widget _buildUserChip(Map<String, dynamic> user) {
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? '';
    final username = email.contains('@') ? email.split('@')[0] : email;
    final isCurrentUser = user['userId'] == widget.currentUserId;

    final chipColor = RoleDisplay.colorFromString(role);

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
              decoration:
                  BoxDecoration(color: chipColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            isCurrentUser ? '$username (Sen)' : username,
            style: TextStyle(
              color: chipColor.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight:
                  isCurrentUser ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberOverview() {
    return StreamBuilder<List<InvitationModel>>(
      stream: _invitationService.getMembersStream(widget.storeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _errorBox('Üye listesi hatası');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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
            // Özet
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Takım Özeti',
                        style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Aktif',
                          activeMembers.length.toString(), Colors.green,
                          Icons.check_circle),
                      _buildStatItem('Bekleyen',
                          pendingInvites.length.toString(), Colors.orange,
                          Icons.schedule),
                      _buildStatItem('Toplam',
                          members.length.toString(), Colors.blue,
                          Icons.group),
                    ],
                  ),
                ],
              ),
            ),

            if (activeMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Aktif Üyeler (${activeMembers.length})',
                          style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...activeMembers.map((m) => _buildMemberTile(m)),
                  ],
                ),
              ),
            ],

            if (pendingInvites.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.2)),
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
                              fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...pendingInvites.map((m) => _buildMemberTile(m)),
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
    final roleColor = RoleDisplay.color(member.role);
    final statusColor = _statusColor(member.status);

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
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: roleColor.withValues(alpha: 0.3)),
            ),
            child:
                Icon(RoleDisplay.icon(member.role), color: roleColor, size: 18),
          ),
          const SizedBox(width: 12),
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
                            color: isCurrentUser
                                ? Colors.blue[700]
                                : Colors.black87),
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
                        child: Text('Siz',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge(member.roleDisplayName, roleColor),
                    if (member.roleSubtitle != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        member.roleSubtitle!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _badge(member.statusDisplayName, statusColor),
                  ],
                ),
                if (member.lastActivity != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Son aktivite: ${_formatLastActivity(member.lastActivity!)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      );

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(msg,
            style: const TextStyle(color: Colors.red, fontSize: 12)),
      );

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Color _statusColor(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.owner: return const Color(0xFF2196F3);
      case InvitationStatus.accepted: return Colors.green;
      case InvitationStatus.invited: return Colors.blue;
      case InvitationStatus.pending: return Colors.orange;
      case InvitationStatus.approved: return Colors.teal;
      case InvitationStatus.rejected: return Colors.red;
    }
  }

  String _formatLastActivity(DateTime lastActivity) {
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
    return 'Az önce';
  }
}
