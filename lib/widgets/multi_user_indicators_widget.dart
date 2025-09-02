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
        SizedBox(height: 8),
        _buildMemberOverview(),
      ],
    );
  }

  Widget _buildOnlineUsers() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _realTimeService.getUserActivityStream(widget.storeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final users = snapshot.data!;
        final onlineUsers = users.where((user) {
          final lastActivity = user['lastActivity'];
          if (lastActivity == null) return false;

          final lastActiveTime = lastActivity.toDate();
          final now = DateTime.now();
          final difference = now.difference(lastActiveTime);

          return difference.inMinutes <
              5; // Active if last activity within 5 minutes
        }).toList();

        if (onlineUsers.isEmpty) {
          return Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: Colors.grey, size: 16),
                SizedBox(width: 8),
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
          padding: EdgeInsets.all(12),
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
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
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
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    onlineUsers.map((user) => _buildUserChip(user)).toList(),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          SizedBox(width: 6),
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
          return SizedBox.shrink();
        }

        final members = snapshot.data!;
        final activeMembers = members.where((m) => m.isActive).toList();
        final pendingInvites = members
            .where((m) =>
                m.status == InvitationStatus.invited ||
                m.status == InvitationStatus.pending)
            .toList();

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.groups, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Takım Durumu',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
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
        );
      },
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 4),
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
}




