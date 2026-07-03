import 'package:flutter/foundation.dart';

import '../config/gemini_config.dart';
import '../models/gemini_model_info.dart';
import '../services/ai_chat_usage_service.dart';
import '../services/report_chat_context_service.dart';
import '../services/report_chat_gemini_service.dart';

/// Sohbet balonu (oturum provider'da tutulur).
class ReportChatMessage {
  final bool isUser;
  final bool isNotice;
  final String text;

  const ReportChatMessage({
    required this.isUser,
    required this.text,
    this.isNotice = false,
  });

  factory ReportChatMessage.welcome(int periodDays) => ReportChatMessage(
        isUser: false,
        text:
            'Merhaba! Son $periodDays günlük mağaza verilerinize göre rapor sorularınızı yanıtlarım.',
      );

  factory ReportChatMessage.notice(String text) =>
      ReportChatMessage(isUser: false, text: text, isNotice: true);
}

/// Rapor asistanı oturumu — ekran kapanınca silinmez (B2).
class ReportChatSessionProvider extends ChangeNotifier {
  final ReportChatGeminiService gemini = ReportChatGeminiService();
  final AiChatUsageService usageService = AiChatUsageService();

  final List<ReportChatMessage> messages = [];

  String selectedModelId = GeminiConfig.defaultModelId;
  int periodDays = ReportChatContextService.defaultPeriodDays;
  Map<String, ModelAvailability> modelAvailability = {};
  Set<String> adminDisabledModels = {};
  bool modelsConfigLoading = false;

  bool _sessionInitialized = false;

  ReportChatGeminiService get chatService => gemini;

  bool get hasActiveChat =>
      gemini.messageCount > 0 || messages.any((m) => m.isUser);

  void ensureSession() {
    if (_sessionInitialized) return;
    _sessionInitialized = true;
    if (messages.isEmpty) {
      messages.add(ReportChatMessage.welcome(periodDays));
    }
  }

  void resetSession() {
    gemini.resetConversation();
    messages.clear();
    messages.add(ReportChatMessage.welcome(periodDays));
    notifyListeners();
  }

  void setPeriodDays(int days) {
    if (days == periodDays) return;
    periodDays = days;
    notifyListeners();
  }

  void setSelectedModel(String modelId) {
    if (modelId == selectedModelId) return;
    selectedModelId = modelId;
    notifyListeners();
  }

  void addMessage(ReportChatMessage message) {
    messages.add(message);
    notifyListeners();
  }

  String get dropdownModelId {
    final status =
        modelAvailability[selectedModelId] ?? ModelAvailability.available;
    if (status.isSelectable &&
        GeminiConfig.availableModels.containsKey(selectedModelId)) {
      return selectedModelId;
    }
    return _firstSelectableModelId() ?? GeminiConfig.defaultModelId;
  }

  String? _firstSelectableModelId() {
    for (final id in GeminiConfig.availableModels.keys) {
      final status = modelAvailability[id] ?? ModelAvailability.available;
      if (status.isSelectable) return id;
    }
    return null;
  }

  void _syncSelectedAfterAvailability() {
    final status =
        modelAvailability[selectedModelId] ?? ModelAvailability.available;
    if (!status.isSelectable) {
      selectedModelId =
          _firstSelectableModelId() ?? GeminiConfig.defaultModelId;
    }
  }

  /// Aşama 1: admin disabled (hızlı) → Aşama 2: RPM/RPD (arka plan).
  Future<void> refreshModelsPhased({bool quotaOnly = false}) async {
    if (!quotaOnly) {
      modelsConfigLoading = true;
      notifyListeners();

      adminDisabledModels = await usageService.fetchAdminDisabledModels();
      modelAvailability =
          usageService.availabilityFromAdmin(adminDisabledModels);
      _syncSelectedAfterAvailability();

      modelsConfigLoading = false;
      notifyListeners();
    }

    final quotaMap = await usageService.refreshQuotaAvailabilities(
      adminDisabledModels,
    );
    modelAvailability = quotaMap;
    adminDisabledModels = quotaMap.entries
        .where((e) => e.value == ModelAvailability.adminDisabled)
        .map((e) => e.key)
        .toSet();
    _syncSelectedAfterAvailability();
    notifyListeners();
  }
}
