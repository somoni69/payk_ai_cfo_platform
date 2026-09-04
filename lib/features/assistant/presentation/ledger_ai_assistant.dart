import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../cubit/assistant_cubit.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';

/// Host for the AI assistant. Open via [LedgerAiAssistantHost.open].
class LedgerAiAssistantHost extends StatelessWidget {
  const LedgerAiAssistantHost({super.key, required this.child});

  final Widget child;

  static void open(BuildContext context, {String? initialModule}) {
    String module = initialModule ?? kAssistantGeneralModule;
    if (initialModule == null) {
      try {
        final path = GoRouterState.of(context).uri.path;
        module = assistantModuleForPath(path);
      } catch (_) {}
    }

    final repo = context.read<AssistantRepository>();

    showLedgerModalSheet<void>(
      context: context,
      expand: true,
      builder: (ctx) => BlocProvider<AssistantCubit>(
        create: (_) => AssistantCubit(repo),
        child: _AssistantPanel(
          initialModule: module,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}

/// Compact AI assistant cube (44×44, radius 12).
class LedgerAiFloatingButton extends StatelessWidget {
  const LedgerAiFloatingButton({super.key, this.onPressed, this.heroTag});

  final VoidCallback? onPressed;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.watch<LanguageCubit>();

    return Tooltip(
      message: language.translate('assistant_title'),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed ?? () => LedgerAiAssistantHost.open(context),
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Icon(TablerIcons.sparkles, color: colors.brand, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantPanel extends StatefulWidget {
  const _AssistantPanel({required this.onClose, this.initialModule});

  final VoidCallback onClose;
  final String? initialModule;

  @override
  State<_AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<_AssistantPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late String _module;
  late String _moduleLabelKey;

  @override
  void initState() {
    super.initState();
    _module = widget.initialModule ?? kAssistantGeneralModule;
    _moduleLabelKey = _labelKeyForModule(_module);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncModuleAndLoad();
    });
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
    context.read<AssistantCubit>().loadHistory(_module);
    _scrollToEnd();
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
    if (question.isEmpty) return;
    _controller.clear();
    context.read<AssistantCubit>().sendMessage(
      question: question,
      module: _module,
    );
    _scrollToEnd();
  }

  Future<void> _clear() async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: LedgerButtons.modalOverlay(ctx),
        child: AlertDialog(
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
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<AssistantCubit>().clearHistory(_module);
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

    return Theme(
      data: LedgerButtons.modalOverlay(context),
      child: Material(
        color: colors.surface,
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: BlocBuilder<AssistantCubit, AssistantState>(
              builder: (context, state) {
                final messages = state.historyFor(_module);
                final loadingHistory = state.isLoading;
                final sending = state.isSendingMessage;
                final error = state.error;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      label: MaterialLocalizations.of(
                        context,
                      ).modalBarrierDismissLabel,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onClose,
                        child: SizedBox(
                          height: 28,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.textSecondary.withValues(
                                  alpha: 0.28,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.sparkles,
                            color: colors.brand,
                            size: 20,
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
                                  '${language.translate('assistant_context')}: $section',
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: language.translate(
                              'assistant_clear_title',
                            ),
                            icon: Icon(
                              TablerIcons.trash,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                            onPressed: messages.isEmpty ? null : _clear,
                          ),
                          IconButton(
                            icon: Icon(
                              TablerIcons.x,
                              size: 20,
                              color: colors.textSecondary,
                            ),
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: loadingHistory
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: LedgerShimmer(
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
                                if (messages.isEmpty && !sending)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      language.translate('assistant_empty'),
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                for (final m in messages) _bubble(context, m),
                                if (sending)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      language.translate('assistant_thinking'),
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.accentAmber,
                                      ),
                                    ),
                                  ),
                                if (error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      language.resolveMessage(error),
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.accentRed,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    if (!loadingHistory && messages.isEmpty && !sending)
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
                                  style: textStyles.smallSans.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                backgroundColor: colors.surfaceNested,
                                side: BorderSide(color: colors.border),
                                onPressed: sending
                                    ? null
                                    : () => _send(
                                        _presetQuestion(language, _module, n),
                                      ),
                              ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: colors.border)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !sending,
                              decoration: InputDecoration(
                                hintText: language.translate(
                                  'assistant_input_hint',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: sending ? null : () => _send(),
                            style: IconButton.styleFrom(
                              backgroundColor: colors.brand,
                              foregroundColor: colors.surface,
                            ),
                            icon: sending
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.surface,
                                    ),
                                  )
                                : const Icon(TablerIcons.send, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, AssistantMessage message) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser ? colors.brand : colors.surfaceNested,
          borderRadius: BorderRadius.circular(12),
          border: isUser ? null : Border.all(color: colors.border),
        ),
        child: Text(
          message.text,
          style: textStyles.bodySans.copyWith(
            color: isUser ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
