import 'package:flutter/material.dart';
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
    _updateUserActivity();
  }

  void _updateUserActivity() async {
    await _realTimeService.updateUserActivity(
      storeId: widget.storeId,
      userId: widget.currentUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildOnlineUsers(),
        const SizedBox(height: 8),
        _buildMemberOverview(),
      ],
    );
  }

  Widget _buildOnlineUsers() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _realTimeService.getUserActivityStream(widget.storeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final users = snapshot.data!;
        final onlineUsers = users.where((user) {
          final lastActivity = user['lastActivity'];
          if (lastActivity == null) return false;

          final lastActiveTime = lastActivity.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastActiveTime);

          return difference.inMinutes < 5; // Active if last activity within 5 minutes
        }).toList();

        if (onlineUsers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Şu anda sadece siz çevrimisiniz',
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
                  Text(
                    'Çevrimiçi Takım (${onlineUsers.length})',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: onlineUsers.map((user) => _buildUserChip(user)).toList(),
              ),
            ],
          ),
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
    return StreamBuilder<List<InvitationModel>>(
      stream: _invitationService.getMembersStream(widget.storeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final members = snapshot.data!;
        final activeMembers = members.where((m) => 
          m.status == InvitationStatus.owner || 
          m.status == InvitationStatus.accepted
        ).toList();
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
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
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
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.orange, size: 16),
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
                          color: isCurrentUser ? Colors.blue[700] : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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