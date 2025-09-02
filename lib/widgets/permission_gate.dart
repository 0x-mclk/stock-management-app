import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_mode.dart';

class PermissionGate extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  final String? upgradeMessage;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.upgradeMessage,
  });

  @override
  Widget build(BuildContext context) {
    final hasPermission = AuthService.instance.hasPermission(permission);

    if (hasPermission) {
      return child;
    }

    return fallback ?? _buildUpgradeWidget(context);
  }

  Widget _buildUpgradeWidget(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.shade50,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            color: Colors.orange.shade600,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            upgradeMessage ?? 'Bu özellik için hesap yükseltmeniz gerekiyor',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (AuthService.instance.isGuestMode()) ...[
                TextButton(
                  onPressed: () => _showUpgradeDialog(context, 'register'),
                  child: const Text('Kayıt Ol'),
                ),
                TextButton(
                  onPressed: () => _showUpgradeDialog(context, 'login'),
                  child: const Text('Giriş Yap'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => _showUpgradeDialog(context, 'upgrade'),
                  child: const Text('Planı Yükselt'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesap Yükseltme'),
        content: Text(_getUpgradeMessage(type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToUpgrade(context, type);
            },
            child: Text(_getActionText(type)),
          ),
        ],
      ),
    );
  }

  String _getUpgradeMessage(String type) {
    switch (type) {
      case 'register':
        return 'Bu özelliği kullanmak için hesap oluşturmanız gerekiyor. '
            'Hesap oluşturduktan sonra tüm verileriniz güvende olacak ve '
            'bulut senkronizasyonu gibi ek özellikler kullanabileceksiniz.';
      case 'login':
        return 'Mevcut hesabınızla giriş yaparak bu özelliği kullanabilirsiniz.';
      case 'upgrade':
        return 'Bu özellik için Pro planına geçmeniz gerekiyor. '
            'Pro planla daha fazla özellik ve sınırsız kullanım hakkı elde edebilirsiniz.';
      default:
        return 'Bu özellik için hesap yükseltmeniz gerekiyor.';
    }
  }

  String _getActionText(String type) {
    switch (type) {
      case 'register':
        return 'Kayıt Ol';
      case 'login':
        return 'Giriş Yap';
      case 'upgrade':
        return 'Planı Yükselt';
      default:
        return 'Devam Et';
    }
  }

  void _navigateToUpgrade(BuildContext context, String type) {
    switch (type) {
      case 'register':
        Navigator.pushNamed(context, '/register');
        break;
      case 'login':
        Navigator.pushNamed(context, '/login');
        break;
      case 'upgrade':
        _showUpgradePlans(context);
        break;
    }
  }

  void _showUpgradePlans(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const UpgradePlansSheet(),
    );
  }
}

class UpgradePlansSheet extends StatelessWidget {
  const UpgradePlansSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final currentMode =
        AuthService.instance.currentSession?.mode ?? UserMode.guest;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planları Karşılaştır',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _buildPlanCard(
                  title: 'Hızlı Başlangıç',
                  subtitle: 'Ücretsiz - Sınırlı',
                  price: 'Ücretsiz',
                  features: [
                    'Temel stok takibi',
                    'Basit satış kayıtları',
                    'Maksimum 100 ürün',
                    'Offline çalışma',
                    'Günde 50 satış',
                  ],
                  isCurrentPlan: currentMode == UserMode.guest,
                  onSelect: null,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  title: 'Basic Plan',
                  subtitle: 'Bireysel kullanım',
                  price: 'Ücretsiz',
                  features: [
                    'Tüm temel özellikler',
                    'Bulut senkronizasyon',
                    '1.000 ürün kapasitesi',
                    'Tedarikçi yönetimi',
                    'Veri dışa aktarma',
                    'Email desteği',
                  ],
                  isCurrentPlan: currentMode == UserMode.basic,
                  onSelect: currentMode == UserMode.guest
                      ? () => _upgradeTo(context, UserMode.basic)
                      : null,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  title: 'Pro Plan',
                  subtitle: 'Küçük işletmeler',
                  price: '₺39/ay',
                  features: [
                    'Tüm Basic özellikler',
                    'Çoklu kullanıcı (3 kişi)',
                    'Sınırsız ürün',
                    'Gelişmiş raporlar',
                    'Stok uyarıları',
                    'Öncelikli destek',
                  ],
                  isCurrentPlan: currentMode == UserMode.pro,
                  isRecommended: true,
                  onSelect:
                      [UserMode.guest, UserMode.basic].contains(currentMode)
                          ? () => _upgradeTo(context, UserMode.pro)
                          : null,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  title: 'Pro Plus Plan',
                  subtitle: 'Büyük işletmeler',
                  price: '₺99/ay',
                  features: [
                    'Tüm Pro özellikler',
                    'Sınırsız kullanıcı',
                    'AI destekli analitik',
                    'API entegrasyonları',
                    'Özel raporlar',
                    '7/24 telefon desteği',
                  ],
                  isCurrentPlan: currentMode == UserMode.proPlus,
                  onSelect: currentMode != UserMode.proPlus
                      ? () => _upgradeTo(context, UserMode.proPlus)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String price,
    required List<String> features,
    required bool isCurrentPlan,
    bool isRecommended = false,
    VoidCallback? onSelect,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended
              ? Colors.blue
              : isCurrentPlan
                  ? Colors.green
                  : Colors.grey.shade300,
          width: isRecommended || isCurrentPlan ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isCurrentPlan ? Colors.green.shade50 : Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRecommended)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Önerilen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentPlan
                      ? Colors.green
                      : isRecommended
                          ? Colors.blue
                          : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isCurrentPlan ? 'Mevcut Plan' : 'Bu Planı Seç',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _upgradeTo(BuildContext context, UserMode mode) {
    // TODO: Implement actual upgrade logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mode.name} planına yükseltme özelliği yakında!'),
        backgroundColor: Colors.blue,
      ),
    );
    Navigator.pop(context);
  }
}




