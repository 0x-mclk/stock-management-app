import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/gemini_config.dart';
import '../models/gemini_model_info.dart';

/// Global AI istek günlüğü ve model limit durumu (Paket B).
class AiChatUsageService {
  static const String requestsCollection = 'ai_chat_requests';
  static const String configCollection = 'ai_config';
  static const String configDocId = 'settings';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// İstek sonrası Firestore'a yazar; hata olursa sessizce geçer.
  Future<void> logRequest({
    required String model,
    required String requestedModel,
    required String actualModel,
    required String status,
    String? storeId,
    int? httpStatus,
    int? tokensTotal,
    bool usedFallback = false,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection(requestsCollection).add({
        'model': model,
        'requestedModel': requestedModel,
        'actualModel': actualModel,
        'userId': user.uid,
        'storeId': storeId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': status,
        if (httpStatus != null) 'httpStatus': httpStatus,
        if (tokensTotal != null) 'tokensTotal': tokensTotal,
        'usedFallback': usedFallback,
      });
    } catch (_) {
      // Offline / rules: ana sohbet akışını kesme
    }
  }

  /// Yönetici tarafından kapatılan modeller.
  ///
  /// Desteklenen Firestore yapıları:
  /// - `ai_config/settings` → alan `disabled_models` veya `disabledModels`
  /// - `ai_config/disabled_models` → aynı alanlar (belge adı farklıysa)
  Future<Set<String>> fetchAdminDisabledModels() async {
    final merged = <String>{};
    try {
      final settings = await _firestore
          .collection(configCollection)
          .doc(configDocId)
          .get(const GetOptions(source: Source.server));
      merged.addAll(_parseDisabledList(settings.data()));

      final altDoc = await _firestore
          .collection(configCollection)
          .doc('disabled_models')
          .get(const GetOptions(source: Source.server));
      merged.addAll(_parseDisabledList(altDoc.data()));
    } catch (_) {
      // Sessiz — UI yine çalışır
    }
    return merged;
  }

  Set<String> _parseDisabledList(Map<String, dynamic>? data) {
    if (data == null) return {};
    final out = <String>{};
    for (final key in ['disabled_models', 'disabledModels', 'models']) {
      final raw = data[key];
      if (raw is List) {
        for (final e in raw) {
          final id = e.toString().trim();
          if (id.isNotEmpty) out.add(id);
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        out.add(raw.trim());
      }
    }
    return out;
  }

  /// Yalnızca admin listesine göre durum (Firestore config — hızlı).
  Map<String, ModelAvailability> availabilityFromAdmin(
    Set<String> adminDisabled,
  ) {
    final result = <String, ModelAvailability>{};
    for (final modelId in GeminiConfig.availableModels.keys) {
      result[modelId] = adminDisabled.contains(modelId)
          ? ModelAvailability.adminDisabled
          : ModelAvailability.available;
    }
    return result;
  }

  /// RPM/RPD sayımı (admin seti önceden biliniyor).
  Future<Map<String, ModelAvailability>> refreshQuotaAvailabilities(
    Set<String> adminDisabled,
  ) async {
    final now = DateTime.now();
    final minuteAgo = now.subtract(const Duration(minutes: 1));
    final startOfDay = DateTime(now.year, now.month, now.day);

    final result = <String, ModelAvailability>{};

    for (final entry in GeminiConfig.availableModels.entries) {
      final modelId = entry.key;
      final info = entry.value;

      if (adminDisabled.contains(modelId)) {
        result[modelId] = ModelAvailability.adminDisabled;
        continue;
      }

      final rpmCount = await _countRequestsSince(modelId, minuteAgo);
      if (rpmCount >= info.requestsPerMinute) {
        result[modelId] = ModelAvailability.atRiskRpm;
        continue;
      }

      final rpdCount = await _countRequestsSince(modelId, startOfDay);
      if (rpdCount >= info.requestsPerDay) {
        result[modelId] = ModelAvailability.atRiskRpd;
        continue;
      }

      result[modelId] = ModelAvailability.available;
    }

    return result;
  }

  /// Tam yenileme (admin + kota).
  Future<Map<String, ModelAvailability>> refreshModelAvailabilities() async {
    final adminDisabled = await fetchAdminDisabledModels();
    return refreshQuotaAvailabilities(adminDisabled);
  }

  Future<int> _countRequestsSince(String modelId, DateTime since) async {
    try {
      final snap = await _firestore
          .collection(requestsCollection)
          .where('model', isEqualTo: modelId)
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(since),
          )
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }
}
