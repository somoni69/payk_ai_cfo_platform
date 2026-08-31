part of 'cash_screen.dart';

extension _CashTabBuilders on _CashViewMixin {
  bool get _hasActiveFilters =>
      _selectedType != 'all' ||
      _selectedPaymentMethod != 'all' ||
      _selectedRegister != 'all' ||
      _selectedCashier != 'all' ||
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
                context.read<CashBloc>().add(_filterEvent(query: val));
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
    final textStyles = context.textStyles;
    final oCcy = localizedDecimalFormat(context);
    final suffix = language.translate('cash_currency_suffix');
    final shift = state.activeShift;
    final summary = state.summaries.isEmpty ? null : state.summaries.first;
    final net = summary?.net;
    final isOpen = shift != null && shift.isOpen;

    final balanceStr = net == null
        ? (isOpen ? '${oCcy.format(shift.startingBalance)} $suffix' : '—')
        : '${oCcy.format(net)} $suffix';

    final label = isOpen
        ? (shift.registerName ?? language.translate('cash_tab_shifts'))
        : language.translate('cash_title');

    final caption = isOpen
        ? language.translate(
            'cash_shift_hero_open',
            params: {
              'time': formatLocalizedDateTime(
                context,
                shift.openedAt,
                style: LocalizedDateTimeStyle.time,
              ),
            },
          )
        : language.translate('cash_shift_hero_closed');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOpen
                      ? colors.accentGreen.withValues(alpha: 0.12)
                      : colors.surfaceNested,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOpen
                            ? colors.accentGreen
                            : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOpen
                          ? language.translate('cash_shift_open')
                          : language.translate('cash_shift_closed'),
                      style: textStyles.captionSans.copyWith(
                        color: isOpen
                            ? colors.accentGreen
                            : colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            balanceStr,
            style: textStyles.h1Mono.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: textStyles.captionSans.copyWith(
              color: isOpen ? colors.accentGreen : colors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (!isViewer) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isOpen
                  ? OutlinedButton(
                      onPressed: () =>
                          _showCloseShiftBottomSheet(context, shift),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        language.translate('cash_close_shift_action'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () =>
                          _showOpenShiftBottomSheet(context, state.registers),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: colors.surface,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        language.translate('cash_open_shift_btn'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFiltersSheet(BuildContext context, CashLoaded state) {
    final language = context.read<LanguageCubit>();
    final textStyles = context.textStyles;
    final colors = context.colors;
    final registerIds = ['all', ...state.registers.map((r) => r.id)];
    final repo = context.read<CashRepository>();
    if (_cashiers.isEmpty) {
      repo.lookupCashiers().then((list) {
        if (!mounted) return;
        _rebuild(() => _cashiers = list);
      });
    }

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_filters'),
      builder: (context, setSheetState) {
        final cashierIds = ['all', ..._cashiers.map((c) => c.id)];
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
                context.read<CashBloc>().add(_filterEvent());
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
                context.read<CashBloc>().add(_filterEvent());
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
                context.read<CashBloc>().add(_filterEvent());
              },
            ),
            const SizedBox(height: 8),
            ExpansibleWidget<String>.selection(
              title: Text(
                _selectedCashier == 'all'
                    ? language.translate('cash_filter_all_cashiers')
                    : (_cashiers
                              .where((c) => c.id == _selectedCashier)
                              .map((c) => c.name)
                              .firstOrNull ??
                          language.translate('cash_filter_all_cashiers')),
                style: textStyles.bodySans,
              ),
              items: cashierIds,
              selectedValue: _selectedCashier,
              itemLabelBuilder: (item) {
                if (item == 'all') {
                  return language.translate('cash_filter_all_cashiers');
                }
                return _cashiers
                        .where((c) => c.id == item)
                        .map((c) => c.name)
                        .firstOrNull ??
                    item;
              },
              onSelected: (val) {
                setSheetState(() => _selectedCashier = val);
                _rebuild();
                context.read<CashBloc>().add(_filterEvent());
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFrom ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked == null) return;
                setSheetState(() => _dateFrom = picked);
                _rebuild();
                if (context.mounted) {
                  context.read<CashBloc>().add(_filterEvent());
                }
              },
              icon: Icon(
                TablerIcons.calendar,
                size: 16,
                color: colors.textSecondary,
              ),
              label: Text(
                _dateFrom == null
                    ? language.translate('cash_filter_date_from')
                    : '${language.translate('cash_filter_date_from')}: ${formatLocalizedDateTime(context, _dateFrom!, style: LocalizedDateTimeStyle.date)}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateTo ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked == null) return;
                setSheetState(() => _dateTo = picked);
                _rebuild();
                if (context.mounted) {
                  context.read<CashBloc>().add(_filterEvent());
                }
              },
              icon: Icon(
                TablerIcons.calendar_event,
                size: 16,
                color: colors.textSecondary,
              ),
              label: Text(
                _dateTo == null
                    ? language.translate('cash_filter_date_to')
                    : '${language.translate('cash_filter_date_to')}: ${formatLocalizedDateTime(context, _dateTo!, style: LocalizedDateTimeStyle.date)}',
              ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: shift.isOpen
                          ? colors.accentGreen.withValues(alpha: 0.12)
                          : colors.surfaceNested,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shift.isOpen
                          ? language.translate('cash_shift_open')
                          : language.translate('cash_shift_closed'),
                      style: textStyles.captionSans.copyWith(
                        color: shift.isOpen
                            ? colors.accentGreen
                            : colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
        itemCount: summaries.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const SalesProfitCard();
          }
          index -= 1;
          final row = summaries[index];
          final isNegativeNet = row.net < 0;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translateMessage(row.registerName),
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (row.hasOpenShift)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          language.translate('cash_shift_open_badge'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.accentGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translate('cash_income'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      "${oCcy.format(row.income)} ${language.translate('cash_currency_suffix')}",
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      "${oCcy.format(row.expense)} ${language.translate('cash_currency_suffix')}",
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentRed,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "${oCcy.format(row.net)} ${language.translate('cash_currency_suffix')}",
                      style: textStyles.h2Sans.copyWith(
                        color: isNegativeNet
                            ? colors.accentRed
                            : colors.accentGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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

class CashOneCKkmView extends StatefulWidget {
  const CashOneCKkmView({super.key});

  @override
  State<CashOneCKkmView> createState() => _CashOneCKkmViewState();
}

class _CashOneCKkmViewState extends State<CashOneCKkmView> {
  OneCKkmOverview? _data;
  String? _error;
  var _loading = true;
  DateTime _dateFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime _dateTo = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  bool get _canLink {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return false;
    return const {
      UserRole.owner,
      UserRole.director,
      UserRole.manager,
      UserRole.accountant,
    }.contains(auth.role);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<CashRepository>().getOneCKkmShifts(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    await _load(refresh: true);
  }

  Future<void> _link({
    required String scope,
    required String onecName,
    int? targetId,
  }) async {
    final language = context.read<LanguageCubit>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<CashRepository>().saveOneCKkmLink(
        scope: scope,
        onecName: onecName,
        targetId: targetId,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translate('cash_onec_linked'))),
      );
      await _load(refresh: true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translateMessage(e.toString()))),
      );
    }
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final period = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickDate(from: true),
              child: Text(
                '${language.translate('cash_onec_date_from')}: ${formatLocalizedDateTime(context, _dateFrom, style: LocalizedDateTimeStyle.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickDate(from: false),
              child: Text(
                '${language.translate('cash_onec_date_to')}: ${formatLocalizedDateTime(context, _dateTo, style: LocalizedDateTimeStyle.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    if (_loading) {
      return Column(
        children: [
          period,
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }
    if (_error != null) {
      return Column(
        children: [
          period,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(language.translateMessage(_error!)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _load,
                      child: Text(language.translate('common_retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    final data = _data;
    if (data == null) {
      return Column(
        children: [
          period,
          Expanded(
            child: Center(
              child: Text(
                language.translate('cash_onec_kkm_empty'),
                style: textStyles.bodySans.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    final onecTotal = _num(data.totals['onec_total']);
    final paykTotal = _num(data.totals['payk_total']);
    final diff = onecTotal - paykTotal;
    final children = <Widget>[
      period,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.translate('cash_tab_onec_kkm'),
                style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.source}${data.syncedAt != null ? ' • ${data.syncedAt}' : ''}${data.error != null ? ' • ${data.error}' : ''}',
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _metricRow(
                context,
                language.translate('cash_onec_total_onec'),
                formatLocalizedNumber(context, onecTotal),
              ),
              const SizedBox(height: 6),
              _metricRow(
                context,
                language.translate('cash_onec_total_payk'),
                formatLocalizedNumber(context, paykTotal),
              ),
              const SizedBox(height: 6),
              _metricRow(
                context,
                language.translate('cash_onec_total_diff'),
                formatLocalizedNumber(context, diff),
                valueColor: diff.abs() < 0.01
                    ? colors.accentGreen
                    : colors.accentRed,
              ),
            ],
          ),
        ),
      ),
    ];

    for (final shift in data.shifts) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift.registerName} · #${shift.number}',
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    shift.cashierName,
                    if (shift.departmentName != null &&
                        shift.departmentName!.isNotEmpty)
                      shift.departmentName,
                    if (shift.paykRegisterName != null)
                      '${language.translate('cash_onec_our')}: ${shift.paykRegisterName}',
                  ].join(' • '),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatLocalizedNumber(context, shift.total),
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${language.translate('cash_onec_cash')}: ${formatLocalizedNumber(context, shift.cashTotal)}  •  ${language.translate('cash_onec_cashless')}: ${formatLocalizedNumber(context, shift.cashlessTotal)}',
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (shift.payments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...shift.payments.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.card.isEmpty ? p.kind : p.card,
                              style: textStyles.captionSans,
                            ),
                          ),
                          Text(
                            formatLocalizedNumber(context, p.amount),
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (data.shifts.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              language.translate('cash_onec_kkm_empty'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
      );
    }

    if (data.mappingRegisters.isNotEmpty ||
        data.mappingDepartments.isNotEmpty ||
        data.mappingCards.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.translate('cash_onec_mapping'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _mappingGroup(
                  context,
                  title: language.translate('cash_onec_map_registers'),
                  rows: data.mappingRegisters,
                  options: data.targetRegisters,
                  scope: 'kkm_register',
                ),
                _mappingGroup(
                  context,
                  title: language.translate('cash_onec_map_departments'),
                  rows: data.mappingDepartments,
                  options: data.targetBranches,
                  scope: 'kkm_department',
                ),
                _mappingGroup(
                  context,
                  title: language.translate('cash_onec_map_cards'),
                  rows: data.mappingCards,
                  options: data.targetBanks,
                  scope: 'kkm_card',
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24 + kLiquidNavClearance),
        children: children,
      ),
    );
  }

  Widget _metricRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
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
          style: textStyles.bodyMono.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _mappingGroup(
    BuildContext context, {
    required String title,
    required List<OneCKkmMappingRow> rows,
    required List<OneCKkmTargetOption> options,
    required String scope,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final language = context.read<LanguageCubit>();
    final textStyles = context.textStyles;
    final canLink = _canLink;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textStyles.captionSans.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...rows.map((row) {
            final items = <int?>[null, ...options.map((o) => o.id)];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExpansibleWidget<int?>.selection(
                title: Text(
                  '${row.onecName}${row.matchedBy == 'auto' ? ' · ${language.translate('cash_onec_auto')}' : ''}',
                  style: textStyles.bodySans,
                ),
                items: items,
                selectedValue: row.targetId,
                itemLabelBuilder: (id) {
                  if (id == null) {
                    return language.translate('cash_onec_not_linked');
                  }
                  return options
                          .where((o) => o.id == id)
                          .map((o) => o.name)
                          .firstOrNull ??
                      language.translate('cash_onec_not_linked');
                },
                onSelected: (id) {
                  if (!canLink) return;
                  _link(scope: scope, onecName: row.onecName, targetId: id);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
