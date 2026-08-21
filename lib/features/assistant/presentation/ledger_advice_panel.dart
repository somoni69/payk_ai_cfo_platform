import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../permissions/cubit/permissions_cubit.dart';
import '../domain/assistant_models.dart';
import '../domain/assistant_repository.dart';

/// Section advice from `GET /assistant/advice` (web AdvicePanel, Ledger style).
///
/// Hidden for roles with [PermissionsCubit.hidesMoney] and on general routes.
class LedgerAdvicePanel extends StatefulWidget {
  const LedgerAdvicePanel({super.key, this.module});

  /// Override route-based module (e.g. dashboard → finance).
  final String? module;

  @override
  State<LedgerAdvicePanel> createState() => _LedgerAdvicePanelState();
}

class _LedgerAdvicePanelState extends State<LedgerAdvicePanel> {
  AdviceResponse? _data;
  var _loading = true;
  var _generating = false;
  var _collapsed = false;
  String? _error;
  String _module = kAssistantGeneralModule;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = GoRouterState.of(context).uri.path;
    final next = widget.module ?? assistantModuleForPath(path);
    if (!_started || next != _module) {
      _started = true;
      _module = next;
      _load();
    }
  }

  Future<void> _load() async {
    if (_module == kAssistantGeneralModule) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lang = context.read<LanguageCubit>().state.languageCode;
      final data = await context.read<AssistantRepository>().getAdvice(
        _module,
        lang: lang,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_generating) return;
    final language = context.read<LanguageCubit>();
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final data = await context.read<AssistantRepository>().generateAdvice(
        _module,
        lang: language.state.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = language.resolveMessage(
          e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidesMoney = context.watch<PermissionsCubit>().hidesMoney;
    if (hidesMoney || _module == kAssistantGeneralModule || _loading) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final content = _data?.isReady == true ? _data!.content : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LedgerCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(TablerIcons.notes, size: 20, color: colors.textSecondary),
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
                        if (_data?.generatedAt != null)
                          Flexible(
                            child: Text(
                              language.translate(
                                'advice_updated',
                                params: {
                                  'time': formatLocalizedDateTime(
                                    context,
                                    _data!.generatedAt!,
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
                if (content != null && !_generating)
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
              if (_generating)
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
                if (content.goal != null &&
                    (content.goal!.value.isNotEmpty ||
                        content.goal!.text.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LedgerCard(
                      backgroundColor: colors.surfaceNested,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.goal!.title.isEmpty
                                ? language.translate('advice_goal')
                                : content.goal!.title,
                            style: textStyles.smallSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          if (content.goal!.value.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(content.goal!.value, style: textStyles.h2Sans),
                          ],
                          if (content.goal!.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              content.goal!.text,
                              style: textStyles.captionSans,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < content.priorities.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LedgerCard(
                      padding: const EdgeInsets.all(12),
                      borderColor: i == 0
                          ? colors.accentAmber
                          : i == 1
                          ? colors.accentGreen
                          : colors.brand,
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
                  LedgerCard(
                    padding: const EdgeInsets.all(12),
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
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
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
  }
}
