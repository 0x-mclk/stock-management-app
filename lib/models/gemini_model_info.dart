/// Gemini model tanımı ve kota limitleri (Paket B / Faz C hazırlığı).
class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.displayName,
    required this.requestsPerMinute,
    required this.tokensPerMinute,
    required this.requestsPerDay,
    this.contextTokenLimit = 1048576,
  });

  final String id;
  final String displayName;
  final int requestsPerMinute;
  final int tokensPerMinute;
  final int requestsPerDay;
  final int contextTokenLimit;

  String get limitSummary =>
      'Dakika: $requestsPerMinute · Günlük: $requestsPerDay istek';
}

/// Model seçilebilirlik / uyarı durumu (Firestore + admin listesi).
enum ModelAvailability {
  available,
  atRiskRpm,
  atRiskRpd,
  adminDisabled,
}

extension ModelAvailabilityX on ModelAvailability {
  bool get isSelectable => this != ModelAvailability.adminDisabled;

  String? get disableReason {
    switch (this) {
      case ModelAvailability.available:
        return null;
      case ModelAvailability.atRiskRpm:
        return 'Dakika istek limiti aşıldı (riskli)';
      case ModelAvailability.atRiskRpd:
        return 'Günlük istek limiti aşıldı (riskli)';
      case ModelAvailability.adminDisabled:
        return 'Yönetici tarafından kapatıldı';
    }
  }
}
