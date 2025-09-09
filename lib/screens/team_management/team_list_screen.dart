import 'package:flutter/material.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Takım Yönetimi',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.person_add_outlined,
                  color: Color(0xFF3498DB)),
              onPressed: () => _navigateToInvite(),
              tooltip: 'Yeni Üye Davet Et',
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.groups_outlined,
                        color: Color(0xFF3498DB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Takım Üyeleri',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mağaza takımınızı profesyonelce yönetin',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Members List
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: StreamBuilder<List<InvitationModel>>(
                stream: _invitationService.getMembersStream(widget.storeId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3498DB),
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade400,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Takım üyeleri yüklenemedi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lütfen daha sonra tekrar deneyin',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final members = snapshot.data ?? [];

                  if (members.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.groups_outlined,
                                size: 48,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Henüz takım üyesi bulunmuyor',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'İlk takım üyenizi davet ederek başlayın',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _navigateToInvite,
                              icon: const Icon(Icons.person_add_outlined,
                                  size: 20),
                              label: const Text('Takım Üyesi Davet Et'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3498DB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
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
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3498DB).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _navigateToInvite,
          backgroundColor: const Color(0xFF3498DB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person_add, size: 24),
        ),
      ),
    );
  }

  Widget _buildMemberCard(InvitationModel member, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getStatusColor(member.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getStatusColor(member.status).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              member.email[0].toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(member.status),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          member.email,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF2C3E50),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3498DB).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  member.roleDisplayName,
                  style: const TextStyle(
                    color: Color(0xFF3498DB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusColor(member.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(member.status).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  member.statusDisplayName,
                  style: TextStyle(
                    color: _getStatusColor(member.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Colors.grey.shade600,
          ),
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
    );
  }

  Color _getStatusColor(InvitationStatus status) {
    switch (status) {
      case InvitationStatus.owner:
        return const Color(0xFF8E44AD); // Professional purple
      case InvitationStatus.accepted:
        return const Color(0xFF27AE60); // Professional green
      case InvitationStatus.invited:
        return const Color(0xFFE67E22); // Professional orange
      case InvitationStatus.pending:
        return const Color(0xFF3498DB); // Professional blue
      case InvitationStatus.rejected:
        return const Color(0xFFE74C3C); // Professional red
      case InvitationStatus.approved:
        return const Color(0xFF16A085); // Professional teal
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
