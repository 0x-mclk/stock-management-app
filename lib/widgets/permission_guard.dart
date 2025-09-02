import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_mode.dart';

class PermissionGuard extends StatelessWidget {
  final Widget child;
  final String permission;
  final Widget? fallback;
  final bool showUpgradeDialog;

  const PermissionGuard({
    super.key,
    required this.child,
    required this.permission,
    this.fallback,
    this.showUpgradeDialog = true,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;

    // Check if user has permission
    if (authService.hasPermission(permission)) {
      return child;
    }

    // Return fallback or upgrade prompt
    return fallback ?? _buildUpgradePrompt(context);
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    if (!showUpgradeDialog) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _showUpgradeDialog(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Colors.orange.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getUpgradeMessage(),
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.orange.shade600,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getUpgradeMessage() {
    switch (permission) {
      case 'canAccessCloudSync':
        return 'Bulut senkronizasyon için hesap oluşturun';
      case 'canInviteUsers':
        return 'Çoklu kullanıcı için Pro\'ya yükseltin';
      case 'canUseAI':
        return 'AI özellikler için Pro Plus\'a yükseltin';
      case 'canExportData':
        return 'Veri dışa aktarma için hesap oluşturun';
      default:
        return 'Bu özellik için yükseltme gerekli';
    }
  }

  void _showUpgradeDialog(BuildContext context) {
    final authService = AuthService.instance;
    final currentMode = authService.currentSession?.mode ?? UserMode.guest;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.star_outline,
              color: Colors.orange.shade600,
            ),
            const SizedBox(width: 8),
            const Text('Özellik Kilidi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getDetailedUpgradeMessage()),
            const SizedBox(height: 16),
            _buildCurrentModeInfo(currentMode),
            const SizedBox(height: 16),
            _buildUpgradeOptions(currentMode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleUpgrade(context, currentMode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yükselt'),
          ),
        ],
      ),
    );
  }

  String _getDetailedUpgradeMessage() {
    switch (permission) {
      case 'canAccessCloudSync':
        return 'Verilerinizi bulutta saklayıp birden fazla cihazdan erişmek için hesap oluşturmanız gerekiyor.';
      case 'canInviteUsers':
        return 'Çalışanlarınızı davet edip birlikte çalışmak için Pro hesaba ihtiyacınız var.';
      case 'canUseAI':
        return 'AI destekli analitik ve öneriler için Pro Plus hesaba yükseltmeniz gerekiyor.';
      case 'canExportData':
        return 'Verilerinizi Excel/PDF formatında dışa aktarmak için hesap oluşturmanız gerekiyor.';
      case 'canManageSuppliers':
        return 'Tedarikçi yönetimi için hesap oluşturmanız gerekiyor.';
      default:
        return 'Bu özelliği kullanmak için hesabınızı yükseltmeniz gerekiyor.';
    }
  }

  Widget _buildCurrentModeInfo(UserMode currentMode) {
    final modeInfo = _getModeInfo(currentMode);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: modeInfo['color'].withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            modeInfo['icon'],
            color: modeInfo['color'],
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mevcut Plan: ${modeInfo['name']}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: modeInfo['color'],
                ),
              ),
              Text(
                modeInfo['description'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeOptions(UserMode currentMode) {
    final List<Map<String, dynamic>> options = [];

    switch (currentMode) {
      case UserMode.guest:
        options.addAll([
          {
            'name': 'Ücretsiz Hesap',
            'description': 'Bulut sync + Tedarikçi yönetimi',
            'color': Colors.green,
            'mode': UserMode.basic,
          },
          {
            'name': 'Pro Hesap',
            'description': 'Çoklu kullanıcı + Gelişmiş raporlar',
            'color': Colors.blue,
            'mode': UserMode.pro,
          },
          {
            'name': 'Pro Plus',
            'description': 'AI özellikler + Sınırsız erişim',
            'color': Colors.purple,
            'mode': UserMode.proPlus,
          },
        ]);
        break;
      case UserMode.basic:
        options.addAll([
          {
            'name': 'Pro Hesap',
            'description': 'Çoklu kullanıcı + Gelişmiş raporlar',
            'color': Colors.blue,
            'mode': UserMode.pro,
          },
          {
            'name': 'Pro Plus',
            'description': 'AI özellikler + Sınırsız erişim',
            'color': Colors.purple,
            'mode': UserMode.proPlus,
          },
        ]);
        break;
      case UserMode.pro:
        options.add({
          'name': 'Pro Plus',
          'description': 'AI özellikler + Sınırsız erişim',
          'color': Colors.purple,
          'mode': UserMode.proPlus,
        });
        break;
      case UserMode.proPlus:
        // Already highest tier
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yükseltme Seçenekleri:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((option) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border:
                    Border.all(color: option['color'].withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.upgrade,
                    color: option['color'],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: option['color'],
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          option['description'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Map<String, dynamic> _getModeInfo(UserMode mode) {
    switch (mode) {
      case UserMode.guest:
        return {
          'name': 'Hızlı Başlangıç',
          'description': 'Offline, temel özellikler',
          'icon': Icons.flash_on,
          'color': Colors.orange,
        };
      case UserMode.basic:
        return {
          'name': 'Ücretsiz Hesap',
          'description': 'Bulut sync, tedarikçi yönetimi',
          'icon': Icons.cloud,
          'color': Colors.green,
        };
      case UserMode.pro:
        return {
          'name': 'Pro Hesap',
          'description': 'Çoklu kullanıcı, gelişmiş raporlar',
          'icon': Icons.business,
          'color': Colors.blue,
        };
      case UserMode.proPlus:
        return {
          'name': 'Pro Plus',
          'description': 'AI özellikler, sınırsız erişim',
          'icon': Icons.auto_awesome,
          'color': Colors.purple,
        };
    }
  }

  void _handleUpgrade(BuildContext context, UserMode currentMode) {
    // This would typically navigate to upgrade flow or show registration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yükseltme özelliği yakında eklenecek!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

// Convenience widget for feature restrictions
class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? requiredPermission;
  final bool enabled;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.onTap,
    this.requiredPermission,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (requiredPermission != null) {
      return PermissionGuard(
        permission: requiredPermission!,
        fallback: _buildCard(context, false),
        child: _buildCard(context, true),
      );
    }

    return _buildCard(context, enabled);
  }

  Widget _buildCard(BuildContext context, bool isEnabled) {
    return Card(
      elevation: isEnabled ? 2 : 1,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isEnabled ? null : Colors.grey.shade100,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isEnabled ? color : Colors.grey,
                size: 24,
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
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isEnabled ? Colors.grey : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEnabled)
                Icon(
                  Icons.lock_outline,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}




