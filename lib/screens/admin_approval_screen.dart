import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invitation_model.dart';
import '../services/invitation_service.dart';

class AdminApprovalScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const AdminApprovalScreen({
    Key? key,
    required this.storeId,
    required this.storeName,
  }) : super(key: key);

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final InvitationService _invitationService = InvitationService.instance;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Davet Onayları'),
        backgroundColor: const Color(0xFF2A5298),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A5298),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bekleyen davet onayları',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Pending approvals list
          Expanded(
            child: StreamBuilder<List<InvitationModel>>(
              stream:
                  _invitationService.getPendingApprovalsStream(widget.storeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Hata: ${snapshot.error}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final pendingInvitations = snapshot.data ?? [];

                if (pendingInvitations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tüm davetler işlenmiş!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bekleyen onay talebi bulunmuyor.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: pendingInvitations.length,
                  itemBuilder: (context, index) {
                    final invitation = pendingInvitations[index];
                    return _buildPendingInvitationCard(invitation);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInvitationCard(InvitationModel invitation) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2A5298),
                  child: Text(
                    invitation.email.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.email,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(invitation.role),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              invitation.roleDisplayName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Davet: ${_formatDate(invitation.invitedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      invitation.emailSent ? Icons.email : Icons.email_outlined,
                      size: 16,
                      color:
                          invitation.emailSent ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      invitation.emailSent
                          ? 'E-posta gönderildi'
                          : 'E-posta gönderilemedi',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            invitation.emailSent ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Davet eden: ${invitation.invitedBy ?? 'Bilinmiyor'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveInvitation(invitation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Onayla'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _rejectInvitation(invitation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _approveInvitation(InvitationModel invitation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daveti Onayla'),
        content: Text(
            '${invitation.email} adresindeki kullanıcının davetini onaylamak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _invitationService.approveInvitation(
        invitationId: invitation.id!,
        adminUserId: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Davet onaylandı!' : 'Onaylama sırasında hata oluştu',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectInvitation(InvitationModel invitation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _reasonController.clear();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daveti Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${invitation.email} adresindeki kullanıcının davetini reddetmek istediğinizden emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Ret sebebi (isteğe bağlı)',
                border: OutlineInputBorder(),
                hintText: 'Reddetme nedeninizi açıklayın...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'confirmed': true,
              'reason': _reasonController.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (result != null && result['confirmed'] == true) {
      final success = await _invitationService.rejectInvitationByAdmin(
        invitationId: invitation.id!,
        adminUserId: user.uid,
        reason: result['reason']?.isNotEmpty == true ? result['reason'] : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Davet reddedildi!' : 'Reddetme sırasında hata oluştu',
            ),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
      }
    }
  }
}
