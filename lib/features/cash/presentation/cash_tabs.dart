part of 'cash_screen.dart';

extension _CashTabBuilders on _CashViewState {
  bool get _hasActiveFilters =>
      _selectedType != 'all' ||
      _selectedPaymentMethod != 'all' ||
      _selectedRegister != 'all' ||
      _dateFrom != null ||
      _dateTo != null;

  Widget _buildOperationsTab(
    BuildContext context,
    CashLoaded state,
    bool isViewer,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final isEmpty = state.filteredTransactions.isEmpty;
    final grouped = _groupedOperationItems(state.filteredTransactions);
    final auth = context.watch<AuthBloc>().state;
    final role = auth is AuthAuthenticated ? auth.role : UserRole.viewer;
    final perms = context.watch<PermissionsCubit>();
    final canEdit = perms.can(
      AppCapability.cash,
      action: PermAction.edit,
      fallbackRole: role,
    );
    final canDelete = perms.can(
      AppCapability.cash,
      action: PermAction.delete,
      fallbackRole: role,
    );

    return RefreshIndicator(
      onRefresh: () => _refreshCash(context),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + kLiquidNavClearance),
        itemCount: 2 + (isEmpty ? 1 : grouped.length),
        separatorBuilder: (context, index) =>
            SizedBox(height: index == 0 ? 14 : 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildShiftHero(context, state, isViewer);
          }
          if (index == 1) {
            return TextField(
              controller: _searchController,
              style: textStyles.bodySans,
              onChanged: (val) {
                context.read<CashBloc>().add(
                  SearchFilterChanged(
                    query: val,
                    filterType: state.filterType,
                    paymentMethod: _selectedPaymentMethod,
                    registerId: _selectedRegister,
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  ),
                );
              },
              decoration: InputDecoration(
                hintText: language.translate('cash_search_counterparty_hint'),
                prefixIcon: Icon(
                  TablerIcons.search,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            );
          }
          if (isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  language.translate('cash_operations_empty'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final item = grouped[index - 2];
          if (item.$1 != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                _operationDayLabel(context, item.$1!),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            );
          }
          final tx = item.$2!;
          return CashTransactionTile(
            transaction: tx,
            onEdit: canEdit && tx.isManual
                ? () => _showEditTransactionSheet(context, tx)
                : null,
            onDelete: canDelete && tx.isManual
                ? () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(language.translate('cash_delete_title')),
                        content: Text(language.translate('cash_delete_msg')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(language.translate('common_cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(language.translate('common_delete')),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      context.read<CashBloc>().add(
                        DeleteTransactionRequested(tx.id),
                      );
                    }
                  }
                : null,
          );
        },
      ),
    );
  }

  List<(DateTime? day, Transaction? tx)> _groupedOperationItems(
    List<Transaction> transactions,
  ) {
    final items = <(DateTime? day, Transaction? tx)>[];
    DateTime? lastDay;
    for (final tx in transactions) {
      final day = DateTime(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );
      if (lastDay != day) {
        items.add((day, null));
        lastDay = day;
      }
      items.add((null, tx));
    }
    return items;
  }

  String _operationDayLabel(BuildContext context, DateTime day) {
    final language = context.read<LanguageCubit>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final key = DateTime(day.year, day.month, day.day);
    if (key == today) return language.translate('cash_group_today');
    if (key == yesterday) return language.translate('cash_group_yesterday');
    return formatLocalizedDateTime(
      context,
      day,
      style: LocalizedDateTimeStyle.date,
    );
  }

  Widget _buildShiftHero(
    BuildContext context,
    CashLoaded state,
    bool isViewer,
  ) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final oCcy = localizedDecimalFormat(context);
    final suffix = language.translate('cash_currency_suffix');
    final shift = state.activeShift;
    final summary = state.summaries.isEmpty ? null : state.summaries.first;
    final net = summary?.net;

    if (shift == null || !shift.isOpen) {
      return LedgerHero(
        label: language.translate('cash_title'),
        value: net == null ? '—' : '${oCcy.format(net)} $suffix',
        caption: language.translate('cash_shift_hero_closed'),
        captionColor: colors.textSecondary,
        trailing: LedgerIconBadge(
          icon: TablerIcons.cash,
          color: colors.textSecondary,
          size: 48,
          iconSize: 24,
        ),
        footer: isViewer
            ? null
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _showOpenShiftBottomSheet(context, state.registers),
                  child: Text(language.translate('cash_open_shift_btn')),
                ),
              ),
      );
    }

    return LedgerHero(
      label: shift.registerName ?? language.translate('cash_tab_shifts'),
      value: net == null
          ? '${oCcy.format(shift.startingBalance)} $suffix'
          : '${oCcy.format(net)} $suffix',
      caption: language.translate(
        'cash_shift_hero_open',
        params: {
          'time': formatLocalizedDateTime(
            context,
            shift.openedAt,
            style: LocalizedDateTimeStyle.time,
          ),
        },
      ),
      captionColor: colors.accentGreen,
      trailing: LedgerIconBadge(
        icon: TablerIcons.cash,
        color: colors.accentGreen,
        size: 48,
        iconSize: 24,
      ),
      footer: isViewer
          ? null
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showCloseShiftBottomSheet(context, shift),
                child: Text(language.translate('cash_close_shift_action')),
              ),
            ),
    );
  }

  void _showFiltersSheet(BuildContext context, CashLoaded state) {
    final language = context.read<LanguageCubit>();
    final textStyles = context.textStyles;
    final registerIds = ['all', ...state.registers.map((r) => r.id)];

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_filters'),
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExpansibleWidget<String>.selection(
              title: Text(
                _selectedType == 'all'
                    ? language.translate('cash_filter_all_types')
                    : (_selectedType == 'income'
                          ? language.translate('cash_income')
                          : language.translate('cash_expense')),
                style: textStyles.bodySans,
              ),
              items: const ['all', 'income', 'expense'],
              selectedValue: _selectedType,
              itemLabelBuilder: (item) {
                if (item == 'income') return language.translate('cash_income');
                if (item == 'expense') {
                  return language.translate('cash_expense');
                }
                return language.translate('cash_filter_all_types');
              },
              onSelected: (val) {
                setSheetState(() => _selectedType = val);
                _rebuild();
                context.read<CashBloc>().add(
                  SearchFilterChanged(
                    query: state.query,
                    filterType: val,
                    paymentMethod: _selectedPaymentMethod,
                    registerId: _selectedRegister,
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ExpansibleWidget<String>.selection(
              title: Text(
                _selectedPaymentMethod == 'all'
                    ? language.translate('cash_filter_all_payment_methods')
                    : language.translate('cash_pm_$_selectedPaymentMethod'),
                style: textStyles.bodySans,
              ),
              items: ['all', ...PaymentMethod.values.map((pm) => pm.name)],
              selectedValue: _selectedPaymentMethod,
              itemLabelBuilder: (item) => item == 'all'
                  ? language.translate('cash_filter_all_payment_methods')
                  : language.translate('cash_pm_$item'),
              onSelected: (val) {
                setSheetState(() => _selectedPaymentMethod = val);
                _rebuild();
                context.read<CashBloc>().add(
                  SearchFilterChanged(
                    query: state.query,
                    filterType: _selectedType,
                    paymentMethod: val,
                    registerId: _selectedRegister,
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            ExpansibleWidget<String>.selection(
              title: Text(
                _selectedRegister == 'all'
                    ? language.translate('cash_filter_all_registers')
                    : (state.registers
                              .where((r) => r.id == _selectedRegister)
                              .map((r) => r.name)
                              .firstOrNull ??
                          language.translate('cash_filter_all_registers')),
                style: textStyles.bodySans,
              ),
              items: registerIds,
              selectedValue: _selectedRegister,
              itemLabelBuilder: (item) {
                if (item == 'all') {
                  return language.translate('cash_filter_all_registers');
                }
                return state.registers
                        .where((r) => r.id == item)
                        .map((r) => r.name)
                        .firstOrNull ??
                    item;
              },
              onSelected: (val) {
                setSheetState(() => _selectedRegister = val);
                _rebuild();
                context.read<CashBloc>().add(
                  SearchFilterChanged(
                    query: state.query,
                    filterType: _selectedType,
                    paymentMethod: _selectedPaymentMethod,
                    registerId: val,
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildShiftsTab(
    BuildContext context,
    CashLoaded state,
    bool isViewer,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.shifts.isEmpty) {
      return Center(
        child: Text(
          language.translate('cash_shifts_empty'),
          style: textStyles.bodySans.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshCash(context),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + kLiquidNavClearance),
        itemCount: state.shifts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final shift = state.shifts[index];
          final diff = shift.difference ?? 0.0;
          final isZeroDiff = diff == 0.0;

          return ExpansibleWidget(
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.registerName ??
                            language.translate('cash_default_register'),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${language.translate('cash_detail_cashier')}: ${shift.cashierName ?? language.translate('role_director')}",
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (shift.isOpen && !isViewer)
                  TextButton(
                    onPressed: () => _showCloseShiftBottomSheet(context, shift),
                    child: Text(language.translate('cash_close_shift_action')),
                  )
                else
                  LedgerPill(
                    text: shift.isOpen
                        ? language.translate('cash_shift_open')
                        : language.translate('cash_shift_closed'),
                    backgroundColor: shift.isOpen
                        ? colors.accentGreen.withValues(alpha: 0.1)
                        : colors.textSecondary.withValues(alpha: 0.1),
                    textColor: shift.isOpen
                        ? colors.accentGreen
                        : colors.textSecondary,
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      language.translate('cash_shift_opened_at'),
                      formatLocalizedDateTime(
                        context,
                        shift.openedAt,
                        style: LocalizedDateTimeStyle.dateTime,
                      ),
                    ),
                    if (shift.closedAt != null) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        context,
                        language.translate('cash_shift_closed_at'),
                        formatLocalizedDateTime(
                          context,
                          shift.closedAt!,
                          style: LocalizedDateTimeStyle.dateTime,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      context,
                      language.translate('cash_shift_start_balance'),
                      "${oCcy.format(shift.startingBalance)} ${language.translate('cash_currency_suffix')}",
                    ),
                    if (shift.endingBalance != null) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        context,
                        language.translate('cash_shift_actual_balance'),
                        "${oCcy.format(shift.endingBalance!)} ${language.translate('cash_currency_suffix')}",
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          language.translate('cash_shift_variance'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          "${oCcy.format(diff)} ${language.translate('cash_currency_suffix')}",
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isZeroDiff
                                ? colors.accentGreen
                                : colors.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryTab(BuildContext context, List<CashSummary> summaries) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (summaries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + kLiquidNavClearance),
        children: [
          const LedgerAdvicePanel(module: 'cash'),
          const SalesProfitCard(),
          const SizedBox(height: 16),
          Center(
            child: Text(
              language.translate('cash_register_summary_empty'),
              style: textStyles.captionSans.copyWith(color: colors.textTooltip),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshCash(context),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + kLiquidNavClearance),
        itemCount: summaries.length + 2,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const LedgerAdvicePanel(module: 'cash');
          }
          if (index == 1) {
            return const SalesProfitCard();
          }
          index -= 2;
          final row = summaries[index];
          final isNegativeNet = row.net < 0;

          return LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translateMessage(row.registerName),
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (row.hasOpenShift)
                      LedgerPill(
                        text: language.translate('cash_shift_open_badge'),
                        backgroundColor: colors.accentGreen.withValues(
                          alpha: 0.1,
                        ),
                        textColor: colors.accentGreen,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translate('cash_income'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      "${oCcy.format(row.income)} ${language.translate('cash_currency_suffix')}",
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translate('cash_expense'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      "${oCcy.format(row.expense)} ${language.translate('cash_currency_suffix')}",
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translate('cash_total'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "${oCcy.format(row.net)} ${language.translate('cash_currency_suffix')}",
                      style: textStyles.h2Sans.copyWith(
                        color: isNegativeNet
                            ? colors.accentRed
                            : colors.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
        Text(
          value,
          style: textStyles.captionSans.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
