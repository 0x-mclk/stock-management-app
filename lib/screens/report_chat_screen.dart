import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../config/gemini_config.dart';
import '../models/gemini_model_info.dart';
import '../providers/realtime_product_provider.dart';
import '../providers/report_chat_session_provider.dart';
import '../providers/role_access_provider.dart';
import '../providers/sales_provider.dart';
import '../services/report_chat_context_service.dart';
import '../services/report_chat_gemini_service.dart';
import '../services/store_selection_service.dart';

class ReportChatScreen extends StatefulWidget {
  const ReportChatScreen({super.key});

  @override
  State<ReportChatScreen> createState() => _ReportChatScreenState();
}

class _ReportChatScreenState extends State<ReportChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  Map<String, dynamic>? _contextCache;
  String? _storeId;

  String? _infoBanner;
  Timer? _infoBannerTimer;
  Timer? _availabilityTimer;
  int _retrySecondsLeft = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    _availabilityTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        context.read<ReportChatSessionProvider>().refreshModelsPhased(
              quotaOnly: true,
            );
      },
    );
  }

  Future<void> _bootstrap() async {
    final session = context.read<ReportChatSessionProvider>();
    session.ensureSession();
    await session.refreshModelsPhased();
    await _prepareContext();
    await _loadStoreId();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _availabilityTimer?.cancel();
    _retryTimer?.cancel();
    _infoBannerTimer?.cancel();
    super.dispose();
  }

  void _showInfoBanner(String message) {
    _infoBannerTimer?.cancel();
    setState(() => _infoBanner = message);
    _infoBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _infoBanner = null);
    });
  }

  void _startRetryCountdown(int seconds) {
    _retryTimer?.cancel();
    setState(() => _retrySecondsLeft = seconds);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_retrySecondsLeft <= 1) {
        t.cancel();
        setState(() => _retrySecondsLeft = 0);
      } else {
        setState(() => _retrySecondsLeft--);
      }
    });
  }

  Future<void> _loadStoreId() async {
    final id = await StoreSelectionService.instance.getCurrentStoreId();
    if (mounted) setState(() => _storeId = id);
  }

  Future<void> _prepareContext() async {
    final salesProvider = context.read<SalesProvider>();
    if (salesProvider.sales.isEmpty) {
      await salesProvider.loadSales();
    }
    if (!mounted) return;
    _refreshContext();
  }

  void _refreshContext() {
    final session = context.read<ReportChatSessionProvider>();
    final sales = context.read<SalesProvider>().sales;
    final products = context.read<RealtimeProductProvider>().products;
    final isYonetici = context.read<RoleAccessProvider>().isYonetici;
    _contextCache = ReportChatContextService().build(
      sales: sales,
      products: products,
      includeFinancials: isYonetici,
      periodDays: session.periodDays,
    );
  }

  List<String> _suggestedQuestions(ReportChatSessionProvider session) => [
        'Son ${session.periodDays} günde en çok satan ürünler hangileri?',
        'Hangi ürünler hiç satılmadı?',
        'Stoku azalan ürünler var mı?',
        'Satışları artırmak için ne önerirsin?',
      ];

  Future<void> _send(String text) async {
    final session = context.read<ReportChatSessionProvider>();
    final question = text.trim();
    if (question.isEmpty || _loading || session.gemini.hasReachedLimit) return;

    if (session.adminDisabledModels.contains(session.selectedModelId)) {
      session.addMessage(
        const ReportChatMessage(
          isUser: false,
          text:
              'Seçili model yönetici tarafından kapatıldı. Lütfen başka bir model seçin.',
        ),
      );
      _scrollToEnd();
      return;
    }

    _refreshContext();
    final contextData = _contextCache;
    if (contextData == null) {
      session.addMessage(
        const ReportChatMessage(
          isUser: false,
          text: 'Veri yüklenemedi. Lütfen biraz sonra tekrar deneyin.',
        ),
      );
      _scrollToEnd();
      return;
    }

    setState(() {
      _loading = true;
      session.addMessage(ReportChatMessage(isUser: true, text: question));
      _inputController.clear();
    });
    _scrollToEnd();

    final isYonetici = context.read<RoleAccessProvider>().isYonetici;
    final result = await session.gemini.ask(
      question: question,
      contextSummary: contextData,
      isYonetici: isYonetici,
      preferredModel: session.selectedModelId,
      storeId: _storeId,
      periodDays: session.periodDays,
      adminDisabledModels: session.adminDisabledModels,
    );

    if (!mounted) return;

    if (result.retryAfterSeconds != null && result.retryAfterSeconds! > 0) {
      _startRetryCountdown(result.retryAfterSeconds!);
    }

    var answerText = result.text;
    if (result.usedFallback && result.actualModel != null) {
      final reqLabel =
          GeminiConfig.infoFor(result.requestedModel)?.displayName ??
              result.requestedModel;
      final actLabel = GeminiConfig.infoFor(result.actualModel!)?.displayName ??
          result.actualModel!;
      answerText =
          'ℹ️ Seçtiğiniz model ($reqLabel) limitte; $actLabel ile yanıtlandı.\n\n$answerText';
    }

    setState(() => _loading = false);
    session.addMessage(ReportChatMessage(isUser: false, text: answerText));
    _scrollToEnd();
    session.refreshModelsPhased(quotaOnly: true);
  }

  String? _tokenDetailLine(ReportChatSessionProvider session) {
    final usage = session.gemini.lastUsage;
    if (usage == null) return null;
    return 'Prompt: ${_formatTokenK(usage.promptTokens)} · '
        'Cevap: ${_formatTokenK(usage.responseTokens)} · '
        'Oturum: ${_formatTokenK(session.gemini.sessionTokenTotal)}';
  }

  String _formatTokenK(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportChatSessionProvider>(
      builder: (context, session, _) {
        final isDesktop = MediaQuery.of(context).size.width >= 700;
        final isNarrow = MediaQuery.of(context).size.width < 500;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Rapor Asistanı'),
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Text(
                    '${session.gemini.messageCount}/${ReportChatGeminiService.maxMessagesPerSession}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yeni sohbet',
                onPressed: _loading
                    ? null
                    : () {
                        session.resetSession();
                        _retryTimer?.cancel();
                        setState(() => _retrySecondsLeft = 0);
                      },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: Column(
            children: [
              _CompactControlBar(
                session: session,
                loading: _loading,
                infoBanner: _infoBanner,
                retrySecondsLeft: _retrySecondsLeft,
                tokenLine: _tokenDetailLine(session),
                showContextWarning: session.gemini
                    .isContextNearlyFull(session.selectedModelId),
                onPeriodChanged: (days) {
                  session.setPeriodDays(days);
                  _refreshContext();
                  _showInfoBanner('Veri paketi güncellendi (son $days gün).');
                },
                onModelChanged: (value) {
                  final prev = session.selectedModelId;
                  session.setSelectedModel(value);
                  if (prev != value) {
                    final label = GeminiConfig.infoFor(value)?.displayName ??
                        value;
                    session.addMessage(
                      ReportChatMessage.notice(
                        'Model: $label olarak güncellendi.',
                      ),
                    );
                  }
                },
                onRefreshModels: () => session.refreshModelsPhased(),
                isNarrow: isNarrow,
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: _suggestedQuestions(session)
                      .map(
                        (q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(q, style: const TextStyle(fontSize: 11)),
                            onPressed: _loading || session.gemini.hasReachedLimit
                                ? null
                                : () => _send(q),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(isDesktop ? 20 : 12),
                  itemCount: session.messages.length + (_loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_loading && index == session.messages.length) {
                      final trying = session.gemini.attemptingModel;
                      final tryingLabel = trying != null
                          ? (GeminiConfig.infoFor(trying)?.displayName ?? trying)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tryingLabel != null
                                    ? 'Analiz ediliyor… ($tryingLabel)'
                                    : 'Analiz ediliyor…',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return _MessageBubble(message: session.messages[index]);
                  },
                ),
              ),
              const Divider(height: 1),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _loading || session.gemini.hasReachedLimit
                              ? null
                              : _send,
                          decoration: InputDecoration(
                            hintText: session.gemini.hasReachedLimit
                                ? 'Oturum limiti doldu — yeni sohbet'
                                : 'Rapor hakkında sorun…',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _loading || session.gemini.hasReachedLimit
                            ? null
                            : () => _send(_inputController.text),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tek satır kompakt kontrol şeridi (B3).
class _CompactControlBar extends StatelessWidget {
  final ReportChatSessionProvider session;
  final bool loading;
  final String? infoBanner;
  final int retrySecondsLeft;
  final String? tokenLine;
  final bool showContextWarning;
  final ValueChanged<int> onPeriodChanged;
  final ValueChanged<String> onModelChanged;
  final VoidCallback onRefreshModels;
  final bool isNarrow;

  const _CompactControlBar({
    required this.session,
    required this.loading,
    required this.infoBanner,
    required this.retrySecondsLeft,
    required this.tokenLine,
    required this.showContextWarning,
    required this.onPeriodChanged,
    required this.onModelChanged,
    required this.onRefreshModels,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    final progress = session.gemini.messageCount /
        ReportChatGeminiService.maxMessagesPerSession;
    final progressColor = progress >= 1
        ? Colors.red.shade700
        : progress >= 0.8
            ? Colors.orange.shade800
            : const Color(0xFF1565C0);

    final alertWidgets = <Widget>[];
    if (infoBanner != null) {
      alertWidgets.add(_AlertChip(text: infoBanner!, color: Colors.green));
    }
    if (retrySecondsLeft > 0) {
      alertWidgets.add(_AlertChip(
        text: 'Kota: ~$retrySecondsLeft sn',
        color: Colors.orange,
      ));
    }
    if (showContextWarning) {
      alertWidgets.add(_AlertChip(
        text: 'Context doluyor — yeni sohbet önerilir',
        color: Colors.amber,
      ));
    }

    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.modelsConfigLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.blue.shade100,
              color: const Color(0xFF1565C0),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: isNarrow ? 118 : 132,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7g')),
                      ButtonSegment(value: 30, label: Text('30g')),
                    ],
                    selected: {session.periodDays},
                    onSelectionChanged: loading
                        ? null
                        : (s) => onPeriodChanged(s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      textStyle: WidgetStateProperty.all(
                        const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.blue.shade100,
                          color: progressColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.gemini.messageCount}/${ReportChatGeminiService.maxMessagesPerSession}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: session.dropdownModelId,
                      onTap: onRefreshModels,
                      items: GeminiConfig.availableModels.entries
                          .map((e) => _modelItem(e.key, e.value))
                          .toList(),
                      onChanged: loading
                          ? null
                          : (v) {
                              if (v != null) onModelChanged(v);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (tokenLine != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tokenLine!,
                  style: TextStyle(fontSize: 9, color: Colors.blue.shade700),
                ),
              ),
            ),
          if (alertWidgets.isNotEmpty)
            isNarrow
                ? ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    title: Text(
                      'Uyarılar (${alertWidgets.length})',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                    ),
                    children: [
                      Wrap(spacing: 6, runSpacing: 4, children: alertWidgets),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: Wrap(spacing: 6, runSpacing: 4, children: alertWidgets),
                  ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _modelItem(String modelId, ModelInfo info) {
    final availability =
        session.modelAvailability[modelId] ?? ModelAvailability.available;
    final reason = availability.disableReason;
    final atRisk = availability == ModelAvailability.atRiskRpm ||
        availability == ModelAvailability.atRiskRpd;

    return DropdownMenuItem<String>(
      value: modelId,
      enabled: availability.isSelectable,
      child: Tooltip(
        message: reason ?? info.limitSummary,
        child: Row(
          children: [
            Expanded(
              child: Text(
                info.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: availability.isSelectable
                      ? null
                      : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (session.modelsConfigLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else if (atRisk)
              Icon(Icons.warning_amber_rounded,
                  size: 14, color: Colors.orange.shade800)
            else if (availability == ModelAvailability.adminDisabled)
              Icon(Icons.block, size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String text;
  final MaterialColor color;

  const _AlertChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color.shade900),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ReportChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isNotice) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message.text,
            style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2196F3) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: isUser
            ? SelectableText(
                message.text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white,
                ),
              )
            : MarkdownBody(
                data: message.text,
                shrinkWrap: true,
                selectable: true,
                styleSheet: _botMarkdownStyle(context),
              ),
      ),
    );
  }

  static MarkdownStyleSheet _botMarkdownStyle(BuildContext context) {
    const base = TextStyle(fontSize: 14, height: 1.45, color: Colors.black87);
    return MarkdownStyleSheet(
      p: base,
      listBullet: base,
      strong: base.copyWith(fontWeight: FontWeight.bold),
      em: base.copyWith(fontStyle: FontStyle.italic),
      h1: base.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      h2: base.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
      h3: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      code: TextStyle(
        fontSize: 13,
        fontFamily: 'monospace',
        backgroundColor: Colors.grey.shade200,
        color: Colors.black87,
      ),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      blockquote: base.copyWith(color: Colors.black54),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.blue.shade300, width: 3),
        ),
      ),
      a: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }
}
