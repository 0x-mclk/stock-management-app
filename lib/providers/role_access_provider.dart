import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/invitation_model.dart';
import '../services/store_selection_service.dart';

/// Uygulama erişim katmanı: yalnızca Yönetici ve Çalışan.
enum AppAccessTier {
  yonetici,
  calisan,
}

class RoleAccessProvider extends ChangeNotifier {
  AppAccessTier _tier = AppAccessTier.yonetici;
  bool _loaded = false;
  bool _loading = false;

  AppAccessTier get tier => _tier;
  bool get isLoaded => _loaded;
  bool get isYonetici => _tier == AppAccessTier.yonetici;
  bool get isCalisan => _tier == AppAccessTier.calisan;

  /// owner + manager → Yönetici; staff + partner → Çalışan
  static AppAccessTier tierFromRoleString(String? role) {
    switch (role) {
      case 'owner':
      case 'manager':
        return AppAccessTier.yonetici;
      case 'staff':
      case 'partner':
        return AppAccessTier.calisan;
      default:
        return AppAccessTier.calisan;
    }
  }

  static AppAccessTier tierFromUserRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
      case UserRole.manager:
        return AppAccessTier.yonetici;
      case UserRole.staff:
      case UserRole.partner:
        return AppAccessTier.calisan;
    }
  }

  /// Ana navigasyon: 0 Ana Sayfa, 1 Ürünler, 2 Satış, 3 Tedarikçiler, 4 Raporlar
  bool canAccessMainTab(int index) {
    if (isYonetici) return true;
    return index >= 0 && index <= 2;
  }

  bool get canViewDashboardSummary => isYonetici;

  bool canUseQuickAction(String actionKey) {
    if (isYonetici) return true;
    const allowed = {'product_add', 'sales', 'price_check', 'report_chat'};
    return allowed.contains(actionKey);
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    await _loadTier();
    _loading = false;
    _loaded = true;
    notifyListeners();
  }

  void reset() {
    _tier = AppAccessTier.yonetici;
    _loaded = false;
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadTier() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _tier = AppAccessTier.yonetici;
      return;
    }

    try {
      final storeId =
          await StoreSelectionService.instance.getCurrentStoreId();

      // Mağaza sahibi her zaman yönetici
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();
      if (storeDoc.exists) {
        final ownerId = storeDoc.data()?['ownerId'] as String?;
        if (ownerId == user.uid) {
          _tier = AppAccessTier.yonetici;
          return;
        }
      }

      // store_invitations (aktif üyelik)
      final invitationSnap = await FirebaseFirestore.instance
          .collection('store_invitations')
          .where('userId', isEqualTo: user.uid)
          .where('storeId', isEqualTo: storeId)
          .where('status', whereIn: ['accepted', 'owner', 'approved'])
          .limit(1)
          .get();

      if (invitationSnap.docs.isNotEmpty) {
        final role = invitationSnap.docs.first.data()['role'] as String?;
        _tier = tierFromRoleString(role);
        return;
      }

      // users koleksiyonu (giriş / davet sonrası kayıtlı rol)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final assignedStore = data['storeId'] as String?;
        if (assignedStore == null ||
            assignedStore.isEmpty ||
            assignedStore == storeId) {
          _tier = tierFromRoleString(data['role'] as String?);
          return;
        }
      }

      // Kendi mağazası (store_uid) — rol yoksa yönetici
      if (storeId == 'store_${user.uid}') {
        _tier = AppAccessTier.yonetici;
        return;
      }

      _tier = AppAccessTier.calisan;
    } catch (_) {
      _tier = AppAccessTier.yonetici;
    }
  }
}

void showRoleAccessDenied(BuildContext context) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text('Yetkiniz yok. Bu işlem için yönetici yetkisi gerekir.'),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}

bool tryNavigateWithRole(
  BuildContext context,
  int index,
  void Function(int) navigate,
) {
  final role = context.read<RoleAccessProvider>();
  if (role.canAccessMainTab(index)) {
    navigate(index);
    return true;
  }
  showRoleAccessDenied(context);
  return false;
}
