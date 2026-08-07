part of 'cash_screen.dart';

extension _CashTabBuilders on _CashViewState {
  Widget _buildOperationsTab(BuildContext context, CashLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final registerIds = ['all', ...state.registers.map((r) => r.id)];

    final isEmpty = state.filteredTransactions.isEmpty;
    final totalItems = isEmpty ? 2 : state.filteredTransactions.length + 1;

    return RefreshIndicator(
      onRefresh: () => _refreshCash(context),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: totalItems,
        separatorBuilder: (context, index) => SizedBox(height: index == 0 ? 8 : 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Системный блок фильтров, который прокручивается вместе со списком операций
            return Container(
              color: colors.surface,
              padding: const EdgeInsets.symmetric(vertical: 4),
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
                              horizontal: 10,
                              vertical: 2,
                            ),
                            tilePadding: EdgeInsets.zero,
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
                                  paymentMethod: _selectedPaymentMethod,
                                  registerId: _selectedRegister,
                                  dateFrom: _dateFrom,
                                  dateTo: _dateTo,
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
                              horizontal: 10,
                              vertical: 2,
                            ),
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              _selectedPaymentMethod == 'all'
                                  ? language.translate(
                                      'cash_filter_all_payment_methods',
                                    )
                                  : language.translate(
                                      'cash_pm_$_selectedPaymentMethod',
                                    ),
                              style: textStyles.captionSans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: [
                              'all',
                              ...PaymentMethod.values.map((pm) => pm.name),
                            ],
                            selectedValue: _selectedPaymentMethod,
                            itemLabelBuilder: (item) {
                              if (item == 'all') {
                                return language.translate(
                                  'cash_filter_all_payment_methods',
                                );
                              }
                              return language.translate('cash_pm_$item');
                            },
                            onSelected: (val) {
                              _rebuild(() => _selectedPaymentMethod = val);
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
                        ),
                        const SizedBox(width: 8),

                        // Фильтр КАССЫ
                        SizedBox(
                          width: 155,
                          child: ExpansibleWidget<String>.selection(
                            cardPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            tilePadding: EdgeInsets.zero,
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
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dateFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked == null || !context.mounted) return;
                            _rebuild(() => _dateFrom = picked);
                            context.read<CashBloc>().add(
                              SearchFilterChanged(
                                query: state.query,
                                filterType: _selectedType,
                                paymentMethod: _selectedPaymentMethod,
                                registerId: _selectedRegister,
                                dateFrom: _dateFrom,
                                dateTo: _dateTo,
                              ),
                            );
                          },
                          icon: const Icon(TablerIcons.calendar, size: 14),
                          label: Text(
                            _dateFrom == null
                                ? language.translate('cash_filter_date_from')
                                : '${_dateFrom!.day}.${_dateFrom!.month}.${_dateFrom!.year}',
                            style: textStyles.captionSans,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dateTo ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked == null || !context.mounted) return;
                            _dateTo = picked;
                            context.read<CashBloc>().add(
                              SearchFilterChanged(
                                query: state.query,
                                filterType: _selectedType,
                                paymentMethod: _selectedPaymentMethod,
                                registerId: _selectedRegister,
                                dateFrom: _dateFrom,
                                dateTo: _dateTo,
                              ),
                            );
                          },
                          icon: const Icon(TablerIcons.calendar, size: 14),
                          label: Text(
                            _dateTo == null
                                ? language.translate('cash_filter_date_to')
                                : '${_dateTo!.day}.${_dateTo!.month}.${_dateTo!.year}',
                            style: textStyles.captionSans,
                          ),
                        ),
                        if (_dateFrom != null || _dateTo != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
                              _rebuild(() {
                                _dateFrom = null;
                                _dateTo = null;
                              });
                              context.read<CashBloc>().add(
                                SearchFilterChanged(
                                  query: state.query,
                                  filterType: _selectedType,
                                  paymentMethod: _selectedPaymentMethod,
                                  registerId: _selectedRegister,
                                ),
                              );
                            },
                            icon: Icon(
                              TablerIcons.x,
                              size: 16,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          if (isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  language.translate('cash_operations_empty'),
                  style: textStyles.bodySans.copyWith(color: colors.textSecondary),
                ),
              ),
            );
          }

          final tx = state.filteredTransactions[index - 1];
          return CashTransactionTile(transaction: tx);
        },
      ),
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
