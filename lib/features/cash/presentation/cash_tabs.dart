part of 'cash_screen.dart';

extension _CashTabBuilders on _CashViewState {
  Widget _buildOperationsTab(BuildContext context, CashLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final registerIds = ['all', ...state.registers.map((r) => r.id)];

    return Column(
      children: [
        // Системный блок фильтров с использованием фирменного ExpansibleWidget.selection
        Container(
          color: colors.surface,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: textStyles.bodySans,
                onChanged: (val) {
                  context.read<CashBloc>().add(
                    SearchFilterChanged(
                      query: val,
                      filterType: state.filterType,
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
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Фильтр ТИПЫ
                    SizedBox(
                      width: 145,
                      child: ExpansibleWidget<String>.selection(
                        cardPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          _selectedType == 'all'
                              ? language.translate('cash_filter_all_types')
                              : (_selectedType == 'income'
                                    ? language.translate('cash_income')
                                    : language.translate('cash_expense')),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: const ['all', 'income', 'expense'],
                        selectedValue: _selectedType,
                        itemLabelBuilder: (item) {
                          if (item == 'income') {
                            return language.translate('cash_income');
                          }
                          if (item == 'expense') {
                            return language.translate('cash_expense');
                          }
                          return language.translate('cash_filter_all_types');
                        },
                        onSelected: (val) {
                          _rebuild(() => _selectedType = val);
                          context.read<CashBloc>().add(
                            SearchFilterChanged(
                              query: state.query,
                              filterType: val,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Фильтр СПОСОБЫ ОПЛАТЫ
                    SizedBox(
                      width: 180,
                      child: ExpansibleWidget<String>.selection(
                        cardPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          _selectedPaymentMethod == 'all'
                              ? language.translate(
                                  'cash_filter_all_payment_methods',
                                )
                              : (_selectedPaymentMethod == 'cash'
                                    ? language.translate('payment_cash')
                                    : language.translate('payment_card')),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: const ['all', 'cash', 'card'],
                        selectedValue: _selectedPaymentMethod,
                        itemLabelBuilder: (item) {
                          if (item == 'cash') {
                            return language.translate('payment_cash');
                          }
                          if (item == 'card') {
                            return language.translate('payment_card');
                          }
                          return language.translate(
                            'cash_filter_all_payment_methods',
                          );
                        },
                        onSelected: (val) {
                          _rebuild(() => _selectedPaymentMethod = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Фильтр КАССЫ
                    SizedBox(
                      width: 155,
                      child: ExpansibleWidget<String>.selection(
                        cardPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          _selectedRegister == 'all'
                              ? language.translate('cash_filter_all_registers')
                              : (state.registers
                                    .firstWhere(
                                      (r) => r.id == _selectedRegister,
                                      orElse: () => CashRegister(
                                        id: '',
                                        name: language.translate('cash'),
                                      ),
                                    )
                                    .name),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: registerIds,
                        selectedValue: _selectedRegister,
                        itemLabelBuilder: (id) {
                          if (id == 'all') {
                            return language.translate(
                              'cash_filter_all_registers',
                            );
                          }
                          final reg = state.registers.firstWhere(
                            (r) => r.id == id,
                            orElse: () => CashRegister(id: id, name: id),
                          );
                          return reg.name;
                        },
                        onSelected: (val) {
                          _rebuild(() => _selectedRegister = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Использование системного ExpansibleWidget для карточек операций
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshCash(context),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: state.filteredTransactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final tx = state.filteredTransactions[index];
                return CashTransactionTile(transaction: tx);
              },
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      return Center(
        child: Text(
          language.translate('cash_register_summary_empty'),
          style: textStyles.captionSans.copyWith(color: colors.textTooltip),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshCash(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: summaries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
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
