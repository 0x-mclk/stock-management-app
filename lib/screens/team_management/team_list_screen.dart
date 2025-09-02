import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/invitation_model.dart';
import '../../services/invitation_service.dart';
import 'invite_partner_screen.dart';

class TeamListScreen extends StatefulWidget {
  final String storeId;
  final String currentUserId;

  const TeamListScreen({
    Key? key,
    required this.storeId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final _invitationService = InvitationService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Takım Yönetimi',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF1E88E5),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () => _navigateToInvite(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF1976D2),
              Colors.grey[50]!,
            ],
            stops: [0.0, 0.2, 0.2],
          ),
        ),
        child: Column(
          children: [
            // Header Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E88E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.groups,
                      color: Color(0xFF1E88E5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Takım Üyeleri',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Mağaza takımınızı yönetin',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),

            // Members List
            Expanded(
              child: StreamBuilder<List<InvitationModel>>(
                stream: _invitationService.getMembersStream(widget.storeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E88E5),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Takım üyeleri yüklenemedi',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final members = snapshot.data ?? [];

                  if (members.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.group_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Henüz takım üyesi yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'İlk takım üyesini davet edin',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _navigateToInvite,
                            icon: const Icon(Icons.add),
                            label: const Text('Partner Davet Et'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return _buildMemberCard(member, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToInvite,
        backgroundColor: Color(0xFF1E88E5),
        child: const Icon(Icons.person_add, color: Colors.white),
      ).animate().scale(delay: 1000.ms),
    );
  }

  Widget _buildMemberCard(InvitationModel member, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(member.status),
          child: Text(
            member.email[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.email,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.roleDisplayName,
                    style: const TextStyle(
                      color: Color(0xFF1E88E5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(member.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    member.statusDisplayName,
                    style: TextStyle(
                      color: _getStatusColor(member.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (member.lastActivity != null) ...[
              const SizedBox(height: 4),
              Text(
                'Son aktiflik: ${_formatDate(member.lastActivity!)}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMemberAction(value, member),
          itemBuilder: (context) => [
            if (member.status == InvitationStatus.invited)
              PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    const Icon(Icons.cancel, size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Daveti İptal Et'),
                  ],
                ),
              ),
            if (member.status == InvitationStatus.accepted)
              PopupMenuItem(
                value: 'deactivate',
                child: Row(
                  children: [
                    const Icon(Icons.pause, size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Devre Dışı Bırak'),
                  ],
                ),
              ),
            if (!member.isActive)
              PopupMenuItem(
                value: 'reactivate',
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow, size: 20, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Yeniden Aktifleştir'),
                  ],
                ),
              ),
            if (member.role != UserRole.owner)
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    const Icon(Icons.delete, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Kaldır'),
                  ],
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 300 + (index * 100)))
        .slideX(begin: 0.2);
  }

  Color _getStatusColor(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.owner:
        return Colors.purple;
      case InvitationStatus.accepted:
        return Colors.green;
      case InvitationStatus.invited:
        return Colors.orange;
      case InvitationStatus.pending:
        return Colors.blue;
      case InvitationStatus.rejected:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }

  void _handleMemberAction(String action, InvitationModel member) async {
    switch (action) {
      case 'cancel':
        await _cancelInvitation(member);
        break;
      case 'deactivate':
        await _deactivateMember(member);
        break;
      case 'reactivate':
        await _reactivateMember(member);
        break;
      case 'remove':
        await _removeMember(member);
        break;
    }
  }

  Future<void> _cancelInvitation(InvitationModel member) async {
    final confirmed = await _showConfirmDialog(
      'Daveti İptal Et',
      '${member.email} adresine gönderilen daveti iptal etmek istediğinizden emin misiniz?',
    );

    if (confirmed) {
      final success = await _invitationService.cancelInvitation(
        storeId: widget.storeId,
        invitationId: member.id!,
      );

      _showResult(success, 'Davet iptal edildi', 'Davet iptal edilemedi');
    }
  }

  Future<void> _deactivateMember(InvitationModel member) async {
    final confirmed = await _showConfirmDialog(
      'Üyeyi Devre Dışı Bırak',
      '${member.email} adresli üyeyi devre dışı bırakmak istediğinizden emin misiniz?',
    );

    if (confirmed) {
      final success = await _invitationService.deactivateMember(
        storeId: widget.storeId,
        memberId: member.id!,
      );

      _showResult(success, 'Üye devre dışı bırakıldı', 'İşlem başarısız');
    }
  }

  Future<void> _reactivateMember(InvitationModel member) async {
    final success = await _invitationService.reactivateMember(
      storeId: widget.storeId,
      memberId: member.id!,
    );

    _showResult(success, 'Üye yeniden aktifleştirildi', 'İşlem başarısız');
  }

  Future<void> _removeMember(InvitationModel member) async {
    final confirmed = await _showConfirmDialog(
      'Üyeyi Kaldır',
      '${member.email} adresli üyeyi tamamen kaldırmak istediğinizden emin misiniz? Bu işlem geri alınamaz.',
    );

    if (confirmed) {
      final success = await _invitationService.removeMember(
        storeId: widget.storeId,
        memberId: member.id!,
      );

      _showResult(success, 'Üye kaldırıldı', 'İşlem başarısız');
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Onayla'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showResult(bool success, String successMessage, String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMessage : errorMessage),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToInvite() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvitePartnerScreen(
          storeId: widget.storeId,
          currentUserId: widget.currentUserId,
        ),
      ),
    );

    if (result == true && mounted) {
      // Refresh the list if needed
      setState(() {});
    }
  }
}
