import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';

/// Host for the full-screen assistant on More. Open via [LedgerAiAssistantHost.open].
class LedgerAiAssistantHost extends StatefulWidget {
  const LedgerAiAssistantHost({super.key, required this.child});

  final Widget child;

  static void open(BuildContext context) {
    final host = context.findAncestorStateOfType<_LedgerAiAssistantHostState>();
    if (host != null) {
      host._openPanel();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.85,
          child: _AssistantPanel(onClose: () => Navigator.of(ctx).pop()),
        ),
      ),
    );
  }

  @override
  State<LedgerAiAssistantHost> createState() => _LedgerAiAssistantHostState();
}

/// Compact AI Assistant Floating Action Button matching the square cube design (44x44, 12px radius).
class LedgerAiFloatingButton extends StatelessWidget {
  const LedgerAiFloatingButton({
    super.key,
    this.onPressed,
    this.heroTag,
  });

  final VoidCallback? onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.watch<LanguageCubit>();

    return Tooltip(
      message: language.translate('assistant_title'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => LedgerAiAssistantHost.open(context),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                TablerIcons.sparkles,
                color: colors.brand,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerAiAssistantHostState extends State<LedgerAiAssistantHost> {
  bool _open = false;

  void _openPanel() => setState(() => _open = true);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_open)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) setState(() => _open = false);
              },
              child: _AssistantPanel(
                onClose: () => setState(() => _open = false),
              ),
            ),
          ),
      ],
    );
  }
}

class _AssistantPanel extends StatefulWidget {
  const _AssistantPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<_AssistantPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<AssistantMessage> _messages = const [];
  bool _loadingHistory = true;
  bool _sending = false;
  String? _error;
  String? _pendingQuestion;
  String _module = kAssistantGeneralModule;
  String _moduleLabelKey = 'assistant_section_general';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncModuleAndLoad();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = GoRouterState.of(context).uri.path;
    final next = assistantModuleForPath(path);
    if (next != _module) {
      _module = next;
      _moduleLabelKey = _labelKeyForModule(next);
      _syncModuleAndLoad();
    }
  }

  String _presetQuestion(LanguageCubit language, String module, int n) {
    final slug = module.replaceAll('-', '_');
    final specific = 'assistant_preset_${slug}_q$n';
    final translated = language.translate(specific);
    if (translated != specific) return translated;
    return language.translate('assistant_q$n');
  }

  String _labelKeyForModule(String module) {
    return switch (module) {
      'cash' => 'nav_cash',
      'finance' || 'dashboard' => 'nav_dashboard',
      'warehouse' => 'nav_warehouse',
      'tasks' || 'my-tasks' => 'nav_tasks',
      'crm' => 'crm_menu',
      'hr' => 'hr_menu',
      'marketing' => 'more_marketing',
      'strategy' => 'more_strategy',
      'legal' => 'more_legal',
      'checklists' => 'more_checklists',
      'reports' => 'more_reports',
      'finance-ops' => 'more_fin_ops',
      'audit' => 'more_audit',
      'branches' => 'more_branches',
      _ => 'assistant_section_general',
    };
  }

  Future<void> _syncModuleAndLoad() async {
    if (!mounted) return;
    setState(() {
      _loadingHistory = true;
      _error = null;
      _pendingQuestion = null;
    });
    try {
      final repo = context.read<AssistantRepository>();
      final history = await repo.getHistory(_module);
      if (!mounted) return;
      setState(() {
        _messages = history;
        _loadingHistory = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty || _sending) return;
    final language = context.read<LanguageCubit>();
    setState(() {
      _sending = true;
      _error = null;
      _pendingQuestion = question;
      _controller.clear();
    });
    _scrollToEnd();
    try {
      final answer = await context.read<AssistantRepository>().ask(
        question: question,
        module: _module,
      );
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _messages = [
          ..._messages,
          AssistantMessage(
            id: -now.millisecondsSinceEpoch,
            role: 'user',
            text: question,
            createdAt: now,
          ),
          AssistantMessage(
            id: -now.millisecondsSinceEpoch - 1,
            role: 'assistant',
            text: answer,
            createdAt: now,
          ),
        ];
        _pendingQuestion = null;
        _sending = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _pendingQuestion = null;
        _error = language.resolveMessage(
          e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  Future<void> _clear() async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(language.translate('assistant_clear_title')),
        content: Text(language.translate('assistant_clear_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colors.accentRed),
            child: Text(language.translate('common_delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AssistantRepository>().clearHistory(_module);
      if (!mounted) return;
      setState(() {
        _messages = const [];
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = language.resolveMessage(
          e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final section = language.translate(_moduleLabelKey);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      TablerIcons.message_circle,
                      size: 20,
                      color: colors.brand,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language.translate('assistant_title'),
                            style: textStyles.h2Sans,
                          ),
                          Text(
                            section,
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: language.translate('assistant_clear'),
                      onPressed: _sending ? null : _clear,
                      icon: Icon(
                        TablerIcons.trash,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(
                        TablerIcons.x,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.border),
              Expanded(
                child: _loadingHistory
                    ? const LedgerShimmer(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                width: 220,
                                height: 44,
                                borderRadius: 12,
                              ),
                              SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ShimmerBox(
                                  width: 180,
                                  height: 36,
                                  borderRadius: 12,
                                ),
                              ),
                              SizedBox(height: 10),
                              ShimmerBox(
                                width: 260,
                                height: 56,
                                borderRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (_messages.isEmpty && _pendingQuestion == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                language.translate('assistant_empty'),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          for (final m in _messages) _bubble(context, m),
                          if (_pendingQuestion != null) ...[
                            _localBubble(
                              context,
                              text: _pendingQuestion!,
                              isUser: true,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                language.translate('assistant_thinking'),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.accentAmber,
                                ),
                              ),
                            ),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _error!,
                                style: textStyles.captionSans.copyWith(
                                  color: colors.accentRed,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (!_loadingHistory && _messages.isEmpty && !_sending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in const [1, 2, 3])
                        ActionChip(
                          label: Text(
                            _presetQuestion(language, _module, n),
                            style: textStyles.smallSans,
                          ),
                          backgroundColor: colors.surfaceNested,
                          side: BorderSide(color: colors.border),
                          onPressed: _sending
                              ? null
                              : () => _send(
                                  _presetQuestion(language, _module, n),
                                ),
                        ),
                    ],
                  ),
                ),
              Divider(height: 1, color: colors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 3,
                        style: textStyles.bodySans,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: language.translate('assistant_placeholder'),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _sending ? null : () => _send(),
                      icon: _sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.brand,
                              ),
                            )
                          : Icon(TablerIcons.send, color: colors.brand),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, AssistantMessage message) {
    return _localBubble(context, text: message.text, isUser: message.isUser);
  }

  Widget _localBubble(
    BuildContext context, {
    required String text,
    required bool isUser,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colors.brand.withValues(alpha: 0.08)
              : colors.surfaceNested,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUser
                ? colors.brand.withValues(alpha: 0.35)
                : colors.border,
          ),
        ),
        child: Text(
          text,
          style: textStyles.captionSans.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}
