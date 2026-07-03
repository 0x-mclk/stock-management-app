import 'package:flutter/material.dart';
import '../models/invitation_model.dart';

/// UI katmanı: uygulamada yalnızca Yönetici ve Çalışan gösterilir.
/// Firestore'da owner/manager → Yönetici, staff/partner → Çalışan.
class RoleDisplay {
  RoleDisplay._();

  static const List<UserRole> invitableRoles = [
    UserRole.manager,
    UserRole.staff,
  ];

  static bool isYoneticiRole(UserRole role) {
    return role == UserRole.owner || role == UserRole.manager;
  }

  static String label(UserRole role) {
    return isYoneticiRole(role) ? 'Yönetici' : 'Çalışan';
  }

  static String labelFromString(String? role) {
    switch (role) {
      case 'owner':
      case 'manager':
        return 'Yönetici';
      default:
        return 'Çalışan';
    }
  }

  /// Mağaza kurucusu (owner) için ek bilgi; diğer rollerde null.
  static String? subtitle(UserRole role) {
    if (role == UserRole.owner) return 'Mağaza sahibi';
    return null;
  }

  static Color color(UserRole role) {
    return isYoneticiRole(role) ? const Color(0xFF2196F3) : const Color(0xFF43A047);
  }

  static Color colorFromString(String? role) {
    return labelFromString(role) == 'Yönetici'
        ? const Color(0xFF2196F3)
        : const Color(0xFF43A047);
  }

  static IconData icon(UserRole role) {
    return isYoneticiRole(role)
        ? Icons.manage_accounts_rounded
        : Icons.person_rounded;
  }

  static String inviteDescription(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return 'Tam erişim: ürünler, satış, tedarikçiler, raporlar, takım yönetimi ve ayarlar.';
      case UserRole.staff:
        return 'Ürün ekleme/düzenleme ve satış. Genel durum özeti gizli; tedarikçi ve raporlar kapalı.';
      default:
        return '';
    }
  }

  static String tierDescriptionYonetici() =>
      'Tüm sayfalar, finansal özetler, tedarikçiler, raporlar ve takım yönetimi.';

  static String tierDescriptionCalisan() =>
      'Ürünler ve satış. Ana sayfa özetleri gizli; tedarikçi, rapor ve takım yönetimi erişimi yok.';
}
