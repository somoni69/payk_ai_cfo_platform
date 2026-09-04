part of 'dashboard_screen.dart';

class _OneCData {
  final OneCReconcileReport onec;
  final List<OneCTarget> targets;

  const _OneCData(this.onec, this.targets);
}

Widget _buildOneCTab(
  BuildContext context,
  OneCReconcileReport? onec,
  List<OneCTarget>? targets,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.watch<LanguageCubit>();
  final authState = context.watch<AuthBloc>().state;
  final canWrite =
      authState is AuthAuthenticated &&
      authState.role.canWrite(AppCapability.dashboard);

  if (onec == null || targets == null) {
    return const DashboardSectionShimmer(kind: DashboardShimmerKind.onec);
  }

  final nothingMatched = onec.matchedCount == 0;
  final diffTotal = onec.matchedDiff;
  final isDiffZero = diffTotal.abs() < 0.01;

  return RefreshIndicator(
    onRefresh: () {
      final bloc = context.read<DashboardBloc>();
      bloc.add(const RefreshOneCReconcileRequested());
      return bloc.stream.firstWhere((state) => state is DashboardLoaded);
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        // --- 1. Сводные метрики (3 карточки) ---
        Row(
          children: [
            Expanded(
              child: LedgerCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('dashboard_onec_total_onec'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatAmount(context, onec.totalOnec)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LedgerCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('dashboard_onec_total_payk'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatAmount(context, onec.totalPayk)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colors.brand,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LedgerCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('dashboard_onec_diff'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nothingMatched
                          ? '—'
                          : '${_formatAmount(context, diffTotal)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: nothingMatched
                            ? colors.textSecondary
                            : (isDiffZero
                                  ? colors.accentGreen
                                  : colors.accentRed),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          nothingMatched
              ? language.translate('dashboard_onec_diff_none')
              : language.translate(
                  'dashboard_onec_diff_basis',
                  params: {
                    'matched': '${onec.matchedCount}',
                    'total': '${onec.matchedCount + onec.unmatchedCount}',
                  },
                ),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        if (onec.unmatchedCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            language.translate(
              'dashboard_onec_unmatched_note',
              params: {'n': '${onec.unmatchedCount}'},
            ),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),

        // --- 2. Кнопка ручного обновления и инфо-блок ---
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.translate('dashboard_tab_onec'),
                    style: textStyles.h2Sans.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${language.translate('dashboard_onec_date')}: ${onec.date}',
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                context.read<DashboardBloc>().add(
                  const RefreshOneCReconcileRequested(),
                );
              },
              icon: const Icon(TablerIcons.refresh),
              label: Text(language.translate('dashboard_onec_refresh')),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // --- 3. Список сопоставлений 1С и PAYK ---
        if (onec.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.surfaceNested,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      TablerIcons.arrows_exchange,
                      size: 26,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    language.translate('dashboard_onec_empty'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...onec.rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildOneCRowCard(context, row, targets, canWrite),
            ),
          ),

        // --- 4. Не найдены в 1С (позиции PAYK без пары) ---
        if (onec.notInOnec.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            language.translate('dashboard_onec_not_in_onec'),
            style: textStyles.h2Sans.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < onec.notInOnec.length; i++) ...[
                  if (i > 0)
                    Divider(height: 16, thickness: 1, color: colors.border),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.surfaceNested,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          onec.notInOnec[i].kind == 'register'
                              ? TablerIcons.cash
                              : TablerIcons.building_bank,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          onec.notInOnec[i].name,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatAmount(context, onec.notInOnec[i].amount)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildOneCRowCard(
  BuildContext context,
  OneCRow row,
  List<OneCTarget> targets,
  bool canWrite,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.watch<LanguageCubit>();
  final diff = row.difference ?? (row.onecAmount - (row.paykAmount ?? 0.0));
  final isMatched = diff.abs() < 0.01 && row.paykId != null;

  return LedgerCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Строка 1С
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.surfaceNested,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                TablerIcons.building,
                size: 16,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.onecName,
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    language.translate('dashboard_onec_col_onec'),
                    style: textStyles.captionSans.copyWith(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_formatAmount(context, row.onecAmount)} TJS',
              style: textStyles.bodyMono.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        Divider(height: 1, thickness: 1, color: colors.border),
        const SizedBox(height: 10),

        // Строка сопоставления в PAYK
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                row.paykKind == 'account'
                    ? TablerIcons.building_bank
                    : TablerIcons.wallet,
                size: 16,
                color: colors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.paykName ??
                        language.translate('dashboard_onec_unlinked'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                      color: row.paykName != null
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                  ),
                  if (row.matchedBy != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      row.matchedBy == 'auto'
                          ? language.translate('dashboard_onec_matched_auto')
                          : language.translate('dashboard_onec_matched_manual'),
                      style: textStyles.captionSans.copyWith(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (row.paykAmount != null)
              Text(
                '${_formatAmount(context, row.paykAmount!)} TJS',
                style: textStyles.bodyMono.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: colors.brand,
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Статус расхождения и кнопка привязки
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMatched
                    ? colors.accentGreen.withValues(alpha: 0.1)
                    : colors.accentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMatched ? TablerIcons.check : TablerIcons.alert_triangle,
                    size: 13,
                    color: isMatched ? colors.accentGreen : colors.accentRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMatched
                        ? language.translate('dashboard_onec_matched')
                        : '${language.translate('dashboard_onec_diff')}: ${_formatAmount(context, diff)} TJS',
                    style: textStyles.captionSans.copyWith(
                      color: isMatched ? colors.accentGreen : colors.accentRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (canWrite)
              InkWell(
                onTap: () => _showOneCLinkModal(context, row, targets),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(TablerIcons.link, size: 14, color: colors.brand),
                      const SizedBox(width: 4),
                      Text(
                        row.paykId == null
                            ? language.translate('dashboard_onec_link_btn')
                            : language.translate('dashboard_onec_change_link'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

void _showOneCLinkModal(
  BuildContext context,
  OneCRow row,
  List<OneCTarget> targets,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final language = context.read<LanguageCubit>();
  final bloc = context.read<DashboardBloc>();

  LedgerBottomSheet.show<void>(
    context: context,
    title: language.translate('dashboard_onec_select_target'),
    builder: (ctx, setSheetState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1С: ${row.onecName}',
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              TablerIcons.link_off,
              color: colors.accentRed,
              size: 20,
            ),
            title: Text(
              language.translate('dashboard_onec_unlink'),
              style: textStyles.bodySans.copyWith(
                color: colors.accentRed,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              bloc.add(
                SaveOneCLinkRequested(
                  onecName: row.onecName,
                  kind: null,
                  targetId: null,
                ),
              );
            },
          ),
          const Divider(height: 1),
          ...targets.map((target) {
            final isSelected =
                row.paykKind == target.kind && row.paykId == target.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                target.kind == 'account'
                    ? TablerIcons.building_bank
                    : TablerIcons.wallet,
                color: isSelected ? colors.brand : colors.textSecondary,
                size: 20,
              ),
              title: Text(
                target.name,
                style: textStyles.bodySans.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.brand : colors.textPrimary,
                ),
              ),
              subtitle: Text(
                '${target.kind == 'account' ? language.translate('dashboard_tab_accounts_rates') : language.translate('dashboard_metric_cash_balance')} • ${_formatAmount(context, target.amount)} TJS',
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              trailing: isSelected
                  ? Icon(TablerIcons.check, color: colors.brand, size: 18)
                  : null,
              onTap: () {
                Navigator.of(ctx).pop();
                bloc.add(
                  SaveOneCLinkRequested(
                    onecName: row.onecName,
                    kind: target.kind,
                    targetId: target.id,
                  ),
                );
              },
            );
          }),
        ],
      );
    },
  );
}
