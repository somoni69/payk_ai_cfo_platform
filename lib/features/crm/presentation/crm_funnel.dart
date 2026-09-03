import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/ledger_layout.dart';
import '../../../core/theme/theme_extensions.dart';
import '../bloc/crm_bloc.dart';
import '../bloc/crm_event.dart';
import '../bloc/crm_state.dart';
import '../domain/crm_models.dart';
import 'crm_labels.dart';
import 'crm_sheets.dart';

/// Открытые стадии — по ним ходят стрелки (won/lost только формой или drag).
const _kOpenStages = <String>['lead', 'contact', 'proposal', 'negotiation'];

/// Горизонтальная воронка: колонки по этапам, сделки скроллятся внутри колонки.
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
    final pickClients = state.pickClients.isNotEmpty
        ? state.pickClients
        : state.clients;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = context.layout;
        final colWidth = layout.funnelColumnWidth(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    layout.funnelBottomPadding,
                  ),
                  itemCount: kDealStages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final stage = kDealStages[index];
                    final deals = state.deals
                        .where((d) => d.stage == stage)
                        .toList();
                    return SizedBox(
                      width: colWidth,
                      child: _StageColumn(
                        stage: stage,
                        deals: deals,
                        canWrite: canWrite,
                        canDelete: canDelete,
                        pickClients: pickClients,
                      ),
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

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.stage,
    required this.deals,
    required this.canWrite,
    required this.canDelete,
    required this.pickClients,
  });

  final String stage;
  final List<CrmDeal> deals;
  final bool canWrite;
  final bool canDelete;
  final List<CrmClient> pickClients;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final sc = crmStageColors(colors, stage);
    final sum = deals.fold<double>(0, (s, d) => s + d.amount);

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
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: highlighting
                ? colors.brand.withValues(alpha: 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(14),
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
                  Expanded(
                    child: Text(
                      crmStageLabel(language, stage),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sc.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${deals.length}',
                      style: textStyles.captionSans.copyWith(
                        color: sc.fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${oCcy.format(sum)} TJS',
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (canWrite) ...[
                const SizedBox(height: 2),
                Text(
                  language.translate('crm_funnel_drag_hint'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: deals.isEmpty
                    ? Center(
                        child: Text(
                          language.translate('crm_funnel_empty_stage'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: deals.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          return _DealCard(
                            deal: deals[i],
                            canWrite: canWrite,
                            canDelete: canDelete,
                            pickClients: pickClients,
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

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.deal,
    required this.canWrite,
    required this.canDelete,
    required this.pickClients,
  });

  final CrmDeal deal;
  final bool canWrite;
  final bool canDelete;
  final List<CrmClient> pickClients;

  bool get _isOpen => _kOpenStages.contains(deal.stage);

  int get _openIdx => _kOpenStages.indexOf(deal.stage);

  void _shift(BuildContext context, int dir) {
    if (!_isOpen) return;
    final nextIdx = _openIdx + dir;
    if (nextIdx < 0) return;
    final next = nextIdx >= _kOpenStages.length ? 'won' : _kOpenStages[nextIdx];
    context.read<CrmBloc>().add(
      SetDealStageRequested(dealId: deal.id, stage: next),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(language.translate('crm_delete_deal')),
        content: Text(
          language.translate(
            'crm_delete_deal_confirm',
            params: {'name': deal.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              language.translate('common_cancel'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              language.translate('common_delete'),
              style: textStyles.captionSans.copyWith(color: colors.accentRed),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<CrmBloc>().add(DeleteDealRequested(deal.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final clientLabel = (deal.clientName != null && deal.clientName!.isNotEmpty)
        ? deal.clientName!
        : language.translate(
            'crm_funnel_client_no',
            params: {'id': deal.clientId},
          );

    final card = Material(
      color: colors.surfaceNested,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: canWrite
            ? () =>
                  showCrmDealForm(context, clients: pickClients, existing: deal)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                clientLabel,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${oCcy.format(deal.amount)} TJS',
                style: textStyles.bodyMono.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                  fontSize: 14,
                ),
              ),
              if (deal.expectedClose != null) ...[
                const SizedBox(height: 2),
                Text(
                  language.translate(
                    'crm_funnel_until',
                    params: {
                      'date': formatLocalizedDateTime(
                        context,
                        deal.expectedClose!,
                        style: LocalizedDateTimeStyle.date,
                      ),
                    },
                  ),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
              if (canWrite && (_isOpen || canDelete)) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_isOpen) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: language.translate('crm_stage_prev'),
                        onPressed: _openIdx <= 0
                            ? null
                            : () => _shift(context, -1),
                        icon: Icon(
                          TablerIcons.chevron_left,
                          size: 18,
                          color: _openIdx <= 0
                              ? colors.textTooltip
                              : colors.textPrimary,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: language.translate('crm_stage_next'),
                        onPressed: () => _shift(context, 1),
                        icon: Icon(
                          TablerIcons.chevron_right,
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (canDelete)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: language.translate('crm_delete_deal'),
                        onPressed: () => _confirmDelete(context),
                        icon: Icon(
                          TablerIcons.trash,
                          size: 16,
                          color: colors.accentRed,
                        ),
                      ),
                  ],
                ),
              ],
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
        child: SizedBox(width: 240, child: Opacity(opacity: 0.92, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
