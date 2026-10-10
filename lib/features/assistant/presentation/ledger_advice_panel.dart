import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../permissions/cubit/permissions_cubit.dart';
import '../cubit/assistant_cubit.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';

/// Section advice from `GET /assistant/advice` (web AdvicePanel, Ledger style).
///
/// Hidden for roles with [PermissionsCubit.hidesMoney] and on general routes.
class LedgerAdvicePanel extends StatelessWidget {
  const LedgerAdvicePanel({super.key, this.module});

  /// Override route-based module (e.g. dashboard → finance).
  final String? module;

  @override
  Widget build(BuildContext context) {
    try {
      context.read<AssistantCubit>();
      return _LedgerAdvicePanelView(module: module);
    } catch (_) {
      return BlocProvider<AssistantCubit>(
        create: (ctx) => AssistantCubit(ctx.read<AssistantRepository>()),
        child: _LedgerAdvicePanelView(module: module),
      );
    }
  }
}

class _LedgerAdvicePanelView extends StatefulWidget {
  const _LedgerAdvicePanelView({this.module});

  final String? module;

  @override
  State<_LedgerAdvicePanelView> createState() => _LedgerAdvicePanelViewState();
}

class _LedgerAdvicePanelViewState extends State<_LedgerAdvicePanelView> {
  var _collapsed = false;
  String _module = kAssistantGeneralModule;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    String? path;
    if (widget.module == null) {
      try {
        path = GoRouterState.of(context).uri.path;
      } catch (_) {
        // Outside a GoRouter subtree there is no route; advice falls back to general.
      }
    }
    final next =
        widget.module ??
        (path != null ? assistantModuleForPath(path) : kAssistantGeneralModule);
    if (!_started || next != _module) {
      _started = true;
      _module = next;
      if (_module != kAssistantGeneralModule) {
        final lang = context.read<LanguageCubit>().state.languageCode;
        context.read<AssistantCubit>().loadAdvice(_module, lang: lang);
      }
    }
  }

  void _generate() {
    final lang = context.read<LanguageCubit>().state.languageCode;
    context.read<AssistantCubit>().generateAdvice(_module, lang: lang);
  }

  @override
  Widget build(BuildContext context) {
    final hidesMoney = context.watch<PermissionsCubit>().hidesMoney;
    if (hidesMoney || _module == kAssistantGeneralModule) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return BlocBuilder<AssistantCubit, AssistantState>(
      builder: (context, state) {
        if (state.isLoading && state.adviceFor(_module) == null) {
          return const SizedBox.shrink();
        }

        final data = state.adviceFor(_module);
        final content = data?.isReady == true ? data?.content : null;
        final generating = state.isGeneratingAdvice;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      TablerIcons.notes,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _collapsed = !_collapsed),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                language.translate('advice_title'),
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (data?.generatedAt case final generatedAt?)
                              Flexible(
                                child: Text(
                                  language.translate(
                                    'advice_updated',
                                    params: {
                                      'time': formatLocalizedDateTime(
                                        context,
                                        generatedAt,
                                        style: LocalizedDateTimeStyle.dateTime,
                                      ),
                                    },
                                  ),
                                  style: textStyles.smallSans.copyWith(
                                    color: colors.textTooltip,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Icon(
                              _collapsed
                                  ? TablerIcons.chevron_down
                                  : TablerIcons.chevron_up,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (content != null && !generating)
                      IconButton(
                        tooltip: language.translate('advice_refresh'),
                        onPressed: _generate,
                        icon: Icon(
                          TablerIcons.refresh,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (!_collapsed) ...[
                  const SizedBox(height: 8),
                  if (generating)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LedgerShimmer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(
                              width: double.infinity,
                              height: 14,
                              borderRadius: 4,
                            ),
                            SizedBox(height: 6),
                            ShimmerBox(width: 220, height: 14, borderRadius: 4),
                          ],
                        ),
                      ),
                    )
                  else if (content == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          language.translate('advice_empty'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _generate,
                            icon: Icon(
                              TablerIcons.refresh,
                              size: 16,
                              color: colors.brand,
                            ),
                            label: Text(language.translate('advice_generate')),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (content.goal case final goal?
                        when goal.value.isNotEmpty || goal.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceNested,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.title.isEmpty
                                    ? language.translate('advice_goal')
                                    : goal.title,
                                style: textStyles.smallSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (goal.value.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(goal.value, style: textStyles.h2Sans),
                              ],
                              if (goal.text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(goal.text, style: textStyles.captionSans),
                              ],
                            ],
                          ),
                        ),
                      ),
                    for (var i = 0; i < content.priorities.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: i == 0
                                  ? colors.accentAmber
                                  : i == 1
                                  ? colors.accentGreen
                                  : colors.brand,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                content.priorities[i].title,
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (content.priorities[i].text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  content.priorities[i].text,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (content.analysis.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language.translate('advice_analysis'),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              content.analysis,
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      language.resolveMessage(state.error!),
                      style: textStyles.captionSans.copyWith(
                        color: colors.accentRed,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
