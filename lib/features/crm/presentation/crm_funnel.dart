import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../bloc/crm_bloc.dart';
import '../bloc/crm_event.dart';
import '../bloc/crm_state.dart';
import '../domain/crm_models.dart';
import 'crm_labels.dart';
import 'crm_sheets.dart';

/// Horizontal kanban funnel: long-press drag deals between stage columns.
class CrmFunnelBoard extends StatelessWidget {
  const CrmFunnelBoard({
    super.key,
    required this.state,
    required this.canWrite,
    required this.canDelete,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final bool canDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (state.deals.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: 240,
              child: Center(
                child: Text(
                  language.translate('crm_no_deals'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colWidth = (constraints.maxWidth * 0.78).clamp(240.0, 300.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final stage in kDealStages) ...[
                    SizedBox(
                      width: colWidth,
                      child: _StageColumn(
                        stage: stage,
                        deals: state.deals
                            .where((d) => d.stage == stage)
                            .toList(),
                        state: state,
                        canWrite: canWrite,
                        canDelete: canDelete,
                      ),
                    ),
                    if (stage != kDealStages.last) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.stage,
    required this.deals,
    required this.state,
    required this.canWrite,
    required this.canDelete,
  });

  final String stage;
  final List<CrmDeal> deals;
  final CrmLoaded state;
  final bool canWrite;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final sc = crmStageColors(colors, stage);
    final sum = deals.fold<double>(0, (s, d) => s + d.amount);
    final stageIdx = kDealStages.indexOf(stage);

    return DragTarget<CrmDeal>(
      onWillAcceptWithDetails: (details) =>
          canWrite && details.data.stage != stage,
      onAcceptWithDetails: (details) {
        context.read<CrmBloc>().add(
          SetDealStageRequested(dealId: details.data.id, stage: stage),
        );
      },
      builder: (context, candidate, rejected) {
        final highlighting = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: highlighting
                ? colors.brand.withValues(alpha: 0.06)
                : colors.surfaceNested,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighting ? colors.brand : colors.border,
              width: highlighting ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sc.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        crmStagePill(language, stage),
                        style: textStyles.captionSans.copyWith(
                          color: sc.fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${deals.length}',
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${oCcy.format(sum)} TJS',
                style: textStyles.smallMono.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              if (deals.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      language.translate('crm_funnel_empty_stage'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: deals.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final deal = deals[i];
                      return _DraggableDealCard(
                        deal: deal,
                        canWrite: canWrite,
                        canDelete: canDelete,
                        stageIdx: stageIdx,
                        pickClients: state.pickClients.isNotEmpty
                            ? state.pickClients
                            : state.clients,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableDealCard extends StatelessWidget {
  const _DraggableDealCard({
    required this.deal,
    required this.canWrite,
    required this.canDelete,
    required this.stageIdx,
    required this.pickClients,
  });

  final CrmDeal deal;
  final bool canWrite;
  final bool canDelete;
  final int stageIdx;
  final List<CrmClient> pickClients;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final card = Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () =>
            showCrmDealForm(context, clients: pickClients, existing: deal),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deal.title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (deal.clientName != null) ...[
                const SizedBox(height: 4),
                Text(
                  deal.clientName!,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${oCcy.format(deal.amount)} TJS',
                style: textStyles.bodyMono.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.brand,
                  fontSize: 14,
                ),
              ),
              if (deal.expectedClose != null) ...[
                const SizedBox(height: 2),
                Text(
                  formatLocalizedDateTime(
                    context,
                    deal.expectedClose!,
                    style: LocalizedDateTimeStyle.date,
                  ),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (canWrite) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: language.translate('crm_stage_prev'),
                      onPressed: stageIdx <= 0
                          ? null
                          : () => context.read<CrmBloc>().add(
                              MoveDealStageRequested(dealId: deal.id, delta: -1),
                            ),
                      icon: const Icon(TablerIcons.chevron_left, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: language.translate('crm_stage_next'),
                      onPressed: stageIdx >= kDealStages.length - 1
                          ? null
                          : () => context.read<CrmBloc>().add(
                              MoveDealStageRequested(dealId: deal.id, delta: 1),
                            ),
                      icon: const Icon(TablerIcons.chevron_right, size: 18),
                    ),
                  ],
                ),
              ],
              if (canWrite)
                Text(
                  language.translate('crm_funnel_drag_hint'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                    fontWeight: FontWeight.w400,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!canWrite) return card;

    return LongPressDraggable<CrmDeal>(
      data: deal,
      feedback: Material(
        color: Colors.transparent,
        elevation: 0,
        child: SizedBox(width: 240, child: Opacity(opacity: 0.92, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
