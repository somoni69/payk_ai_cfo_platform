import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/locale_date_time_format.dart';
import '../../core/localization/locale_number_format.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/cash/bloc/cash_bloc.dart';
import '../../features/cash/bloc/cash_event.dart';
import '../../features/cash/bloc/cash_state.dart';
import '../../features/cash/domain/transaction_model.dart';
import '../../features/cash/domain/cash_repository.dart';
import '../widgets/ledger_operation_row.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_collapsing_header.dart';

/// Точка входа в кассовый модуль с внедрением CashBloc.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();

    return BlocProvider<CashBloc>(
      create: (context) =>
          CashBloc(context.read<CashRepository>())..add(LoadCashData()),
      child: const CashView(),
    );
  }
}

class CashView extends StatefulWidget {
  const CashView({super.key});

  @override
  State<CashView> createState() => _CashViewState();
}

class _CashViewState extends State<CashView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshCash(BuildContext context) {
    final completion = Completer<void>();
    context.read<CashBloc>().add(LoadCashData(completion: completion));
    return completion.future;
  }

  String _formatAmount(BuildContext context, double amount) {
    return formatLocalizedNumber(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final authState = context.watch<AuthBloc>().state;
    final isViewer =
        authState is! AuthAuthenticated ||
        !authState.role.canManage(AppCapability.cash);

    return BlocConsumer<CashBloc, CashState>(
      listener: (context, state) {
        if (state is CashLoaded && state.errorMessage != null) {
          // Показ оповещений (об ошибках или результате закрытия смены)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                language.translateMessage(state.errorMessage!),
                style: textStyles.bodySans.copyWith(color: colors.surface),
              ),
              backgroundColor:
                  state.errorMessage!.contains('Внимание') ||
                      state.errorMessage!.contains('Ошибка')
                  ? colors.accentRed
                  : (state.errorMessage!.contains('успешно')
                        ? colors.accentGreen
                        : colors.textPrimary),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is CashLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is CashError) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.alert_triangle,
                      color: colors.accentRed,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      language.translateMessage(state.message),
                      style: textStyles.bodySans,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<CashBloc>().add(LoadCashData());
                      },
                      child: Text(language.translate('common_retry')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is CashLoaded) {
          final isShiftOpen = state.activeShift != null;

          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  LedgerCollapsingHeader(
                    title: language.translate('cash_title'),
                    pinned: true,
                    floating: true,
                    snap: true,
                    actions: [
                      if (!isViewer && isShiftOpen) ...[
                        IconButton(
                          icon: const Icon(TablerIcons.plus),
                          onPressed: () => _showAddTransactionBottomSheet(
                            context,
                            authState,
                            state.registers,
                          ),
                          tooltip: language.translate('cash_add_operation'),
                        ),
                      ],
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: colors.brand,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: colors.brand,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: colors.border,
                      labelStyle: textStyles.captionSans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: textStyles.captionSans.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: [
                        Tab(text: language.translate('cash_tab_operations')),
                        Tab(text: language.translate('cash_tab_registers')),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                Column(
                  children: [
                    // Фиксированная и закрепленная панель поиска и фильтров (НЕ срезается и всегда видна)
                    Container(
                      color: colors.surface,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
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
                                        hintText: language.translate(
                                          'cash_search_hint',
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        prefixIcon: Icon(
                                          TablerIcons.search,
                                          size: 18,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  context,
                                  language.translate('cash_filter_all'),
                                  'all',
                                  state.query,
                                  state.filterType,
                                ),
                                const SizedBox(width: 4),
                                _buildFilterChip(
                                  context,
                                  language.translate('cash_income'),
                                  'income',
                                  state.query,
                                  state.filterType,
                                ),
                                const SizedBox(width: 4),
                                _buildFilterChip(
                                  context,
                                  language.translate('cash_expense'),
                                  'expense',
                                  state.query,
                                  state.filterType,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),

                    // Список смены и операций (скроллируется ПОД поиском)
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _refreshCash(context),
                        child: Builder(
                          builder: (context) {
                            final hasShift = state.activeShift != null;
                            final shiftCount = hasShift ? 1 : 0;
                            final txCount = state.filteredTransactions.isEmpty
                                ? 1
                                : state.filteredTransactions.length;
                            final totalCount = shiftCount + txCount;

                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: totalCount,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                if (hasShift && index == 0) {
                                  return _buildShiftStatusBanner(
                                    context,
                                    state.activeShift,
                                    isViewer,
                                  );
                                }

                                final txIndex = index - shiftCount;
                                if (state.filteredTransactions.isEmpty) {
                                  return SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: Text(
                                        language.translate(
                                          'cash_operations_not_found',
                                        ),
                                        style: textStyles.captionSans.copyWith(
                                          color: colors.textTooltip,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final tx = state.filteredTransactions[txIndex];
                                return LedgerOperationRow(
                                  title: language.translateMessage(tx.title),
                                  category: language.translate(
                                    'cash_transaction_details',
                                    params: {
                                      'category': _categoryLabel(
                                        language,
                                        tx.category,
                                      ),
                                      'paymentMethod': _paymentMethodLabel(
                                        language,
                                        tx.paymentMethod,
                                      ),
                                    },
                                  ),
                                  amount: language.translate(
                                    'cash_signed_amount_tjs',
                                    params: {
                                      'sign': tx.isIncome ? '+' : '-',
                                      'amount': _formatAmount(
                                        context,
                                        tx.amount,
                                      ),
                                    },
                                  ),
                                  isIncome: tx.isIncome,
                                  pillText: tx.cashierName == 'Система'
                                      ? language.translate(
                                          'cash_cashier_system',
                                        )
                                      : language.translateMessage(
                                          tx.cashierName,
                                        ),
                                  pillColor: colors.brand.withValues(
                                    alpha: 0.1,
                                  ),
                                  pillTextColor: colors.brand,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                _buildSummaryTab(context, state.summaries),
              ],
            ),
          ),
        );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildShiftStatusBanner(
    BuildContext context,
    CashShift? activeShift,
    bool isViewer,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final isOpen = activeShift != null;

    return Container(
      color: isOpen
          ? colors.accentGreen.withValues(alpha: 0.05)
          : colors.accentRed.withValues(alpha: 0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            isOpen ? TablerIcons.lock_open : TablerIcons.lock,
            color: isOpen ? colors.accentGreen : colors.accentRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen
                      ? language.translate('cash_shift_open')
                      : language.translate('cash_shift_closed'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isOpen ? colors.accentGreen : colors.accentRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOpen
                      ? language.translate(
                          'cash_shift_open_details',
                          params: {
                            'time': formatLocalizedDateTime(
                              context,
                              activeShift.openedAt,
                              style: LocalizedDateTimeStyle.time,
                            ),
                            'balance': _formatAmount(
                              context,
                              activeShift.startingBalance,
                            ),
                          },
                        )
                      : language.translate('cash_shift_operations_blocked'),
                  style: textStyles.smallSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isViewer) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                if (isOpen) {
                  _showCloseShiftDialog(context);
                } else {
                  _showOpenShiftDialog(context);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: isOpen ? colors.accentRed : colors.accentGreen,
                side: BorderSide(
                  color: isOpen
                      ? colors.accentRed.withValues(alpha: 0.5)
                      : colors.accentGreen.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(
                isOpen
                    ? language.translate('common_close')
                    : language.translate('common_open'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String type,
    String currentQuery,
    String currentFilterType,
  ) {
    final isSelected = currentFilterType == type;
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.read<CashBloc>().add(
              SearchFilterChanged(query: currentQuery, filterType: type),
            );
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? colors.brand : colors.surface,
              border: Border.all(
                color: isSelected ? colors.brand : colors.border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: textStyles.smallSans.copyWith(
                color: isSelected ? colors.surface : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOpenShiftDialog(BuildContext context) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final controller = TextEditingController(text: '5000');

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            title: Text(
              language.translate('cash_open_shift_title'),
              style: textStyles.h2Sans,
            ),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodyMono,
              decoration: InputDecoration(
                labelText: language.translate('cash_starting_balance_label'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(language.translate('common_cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final bal = parseLocalizedNumber(context, controller.text);
                  if (bal != null) {
                    context.read<CashBloc>().add(OpenShiftRequested(bal));
                    Navigator.pop(dialogCtx);
                  }
                },
                child: Text(language.translate('cash_open_shift_action')),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showCloseShiftDialog(BuildContext context) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final controller = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            title: Text(
              language.translate('cash_close_shift_title'),
              style: textStyles.h2Sans,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.translate('cash_close_shift_instruction'),
                  style: textStyles.captionSans,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodyMono,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_actual_balance_label'),
                    hintText: language.translate('cash_actual_balance_hint'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(language.translate('common_cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  final bal = parseLocalizedNumber(context, controller.text);
                  if (bal != null) {
                    context.read<CashBloc>().add(CloseShiftRequested(bal));
                    Navigator.pop(dialogCtx);
                  }
                },
                child: Text(language.translate('cash_close_shift_action')),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildSummaryTab(BuildContext context, List<CashSummary> summaries) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
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
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final row = summaries[index];

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
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (row.hasOpenShift)
                      LedgerPill(
                        text: language.translate('cash_shift_open_badge'),
                        backgroundColor: colors.accentGreen.withValues(
                          alpha: 0.1,
                        ),
                        textColor: colors.accentGreen,
                      )
                    else
                      LedgerPill(
                        text: language.translate('cash_shift_closed_badge'),
                        backgroundColor: colors.textSecondary.withValues(
                          alpha: 0.1,
                        ),
                        textColor: colors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translate('cash_summary_income'),
                      style: textStyles.smallSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      language.translate(
                        'cash_amount_tjs',
                        params: {'amount': oCcy.format(row.income)},
                      ),
                      style: textStyles.bodyMono.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.translate('cash_summary_expense'),
                      style: textStyles.smallSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      language.translate(
                        'cash_amount_tjs',
                        params: {'amount': oCcy.format(row.expense)},
                      ),
                      style: textStyles.bodyMono.copyWith(
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
                      language.translate('cash_summary_net_flow'),
                      style: textStyles.smallSans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      language.translate(
                        'cash_signed_amount_tjs',
                        params: {
                          'sign': row.net >= 0 ? '+' : '',
                          'amount': oCcy.format(row.net),
                        },
                      ),
                      style: textStyles.bodyMono.copyWith(
                        color: row.net >= 0
                            ? colors.accentGreen
                            : colors.accentRed,
                        fontWeight: FontWeight.bold,
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

  String _categoryLabel(LanguageCubit language, String category) {
    final translationKey = switch (category) {
      'sales' => 'cash_category_sales',
      'services' => 'cash_category_services',
      'advance' => 'cash_category_advance',
      'refund_in' => 'cash_category_refund',
      'other_income' => 'cash_category_other_income',
      'rent' => 'cash_category_rent',
      'salary' => 'cash_category_salary',
      'goods' => 'cash_category_goods',
      'utilities' => 'cash_category_utilities',
      'marketing' => 'cash_category_marketing',
      'transport' => 'cash_category_transport',
      'taxes' => 'cash_category_taxes',
      'other_expense' => 'cash_category_other_expense',
      _ => null,
    };

    return translationKey == null
        ? language.translateMessage(category)
        : language.translate(translationKey);
  }

  String _paymentMethodLabel(
    LanguageCubit language,
    PaymentMethod paymentMethod,
  ) {
    final translationKey = switch (paymentMethod) {
      PaymentMethod.cash => 'cash_payment_cash',
      PaymentMethod.card => 'cash_payment_card',
      PaymentMethod.alif => 'cash_payment_alif',
      PaymentMethod.dushanbeCity => 'cash_payment_dushanbe_city',
      PaymentMethod.ocms => 'cash_payment_ocms',
    };

    return language.translate(translationKey);
  }

  Future<void> _showAddTransactionBottomSheet(
    BuildContext context,
    AuthState authState,
    List<CashRegister> registers,
  ) async {
    final cashBloc = context.read<CashBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    final formKey = GlobalKey<FormState>();
    bool isIncome = true;
    PaymentMethod paymentMethod = PaymentMethod.cash;
    String selectedRegisterId = registers.isNotEmpty ? registers[0].id : '';
    String selectedCategory = '';

    final TextEditingController amountController = TextEditingController();
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    const incomeCategories = [
      'sales',
      'services',
      'advance',
      'refund_in',
      'other_income',
    ];
    const expenseCategories = [
      'rent',
      'salary',
      'goods',
      'utilities',
      'marketing',
      'transport',
      'taxes',
      'other_expense',
    ];

    String getCategoryLabel(String key) {
      return _categoryLabel(language, key);
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('cash_new_operation'),
        builder: (context, setSheetState) {
          return Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Переключатель Приход / Расход
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeButton(
                        context,
                        language.translate('cash_income'),
                        true,
                        isIncome,
                        colors.accentGreen,
                        (value) {
                          setSheetState(() => isIncome = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeButton(
                        context,
                        language.translate('cash_expense'),
                        false,
                        isIncome,
                        colors.accentRed,
                        (value) {
                          setSheetState(() => isIncome = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Касса (Register)
                if (registers.isNotEmpty) ...[
                  Text(
                    language.translate('cash_register'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpansibleWidget<String>.selection(
                    cardPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    title: Text(
                      language.translateMessage(
                        registers
                            .firstWhere(
                              (r) => r.id == selectedRegisterId,
                              orElse: () => registers[0],
                            )
                            .name,
                      ),
                      style: textStyles.bodySans,
                    ),
                    items: registers.map((r) => r.id).toList(),
                    selectedValue: selectedRegisterId,
                    itemLabelBuilder: (id) => language.translateMessage(
                      registers.firstWhere((r) => r.id == id).name,
                    ),
                    onSelected: (val) {
                      setSheetState(() => selectedRegisterId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Поле Сумма
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? language.translate('cash_amount_required')
                      : null,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_operation_amount'),
                    hintText:
                        '${formatLocalizedNumber(context, 0, minimumFractionDigits: 2, maximumFractionDigits: 2, useGrouping: false)} TJS',
                    prefixIcon: Icon(
                      TablerIcons.coin,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Способ оплаты
                Text(
                  language.translate('cash_payment_method'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPaymentMethodsRow(context, language, paymentMethod, (
                  value,
                ) {
                  setSheetState(() => paymentMethod = value);
                }),
                const SizedBox(height: 16),

                // Категория
                Text(
                  language.translate('cash_category'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ExpansibleWidget<String>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    selectedCategory.isEmpty
                        ? language.translate('cash_select_category')
                        : getCategoryLabel(selectedCategory),
                    style: textStyles.bodySans,
                  ),
                  items: isIncome ? incomeCategories : expenseCategories,
                  selectedValue: selectedCategory,
                  itemLabelBuilder: (cat) => getCategoryLabel(cat),
                  onSelected: (val) {
                    setSheetState(() => selectedCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                // Поле Получатель / Контрагент
                TextFormField(
                  controller: titleController,
                  style: textStyles.bodySans,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? language.translate('cash_counterparty_required')
                      : null,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_counterparty'),
                    hintText: language.translate('cash_counterparty_hint'),
                    prefixIcon: Icon(
                      TablerIcons.user,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Описание
                TextFormField(
                  controller: descriptionController,
                  style: textStyles.bodySans,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: language.translate('cash_description'),
                    hintText: language.translate('cash_description_hint'),
                    prefixIcon: Icon(
                      TablerIcons.notes,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: () {
              if (selectedCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      language.translate('cash_select_category_required'),
                    ),
                    backgroundColor: colors.accentRed,
                  ),
                );
                return;
              }
              if (formKey.currentState!.validate()) {
                final amount = parseLocalizedNumber(
                  context,
                  amountController.text,
                );
                if (amount != null) {
                  // Вычисляем имя кассира
                  String cashierName = 'Система';
                  if (authState is AuthAuthenticated) {
                    cashierName = authState.username;
                  }

                  final newTx = Transaction(
                    id: '',
                    title: titleController.text.trim(),
                    category: selectedCategory,
                    amount: amount,
                    isIncome: isIncome,
                    paymentMethod: paymentMethod,
                    dateTime: DateTime.now(),
                    cashierName: cashierName,
                    registerId: selectedRegisterId.isNotEmpty
                        ? selectedRegisterId
                        : null,
                  );

                  cashBloc.add(AddTransactionRequested(newTx));
                  Navigator.pop(context);
                }
              }
            },
            child: Text(language.translate('cash_record')),
          );
        },
      );
    } finally {
      amountController.dispose();
      titleController.dispose();
      descriptionController.dispose();
    }
  }

  Widget _buildTypeButton(
    BuildContext context,
    String label,
    bool isIncomeType,
    bool currentIsIncome,
    Color activeColor,
    Function(bool) onTap,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isSelected = currentIsIncome == isIncomeType;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onTap(isIncomeType),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.1)
                  : colors.surface,
              border: Border.all(
                color: isSelected ? activeColor : colors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: textStyles.captionSans.copyWith(
                color: isSelected ? activeColor : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsRow(
    BuildContext context,
    LanguageCubit language,
    PaymentMethod selectedMethod,
    ValueChanged<PaymentMethod> onTap,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: PaymentMethod.values.map((method) {
        final isSelected = selectedMethod == method;
        return Semantics(
          button: true,
          selected: isSelected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTap(method),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.brand.withValues(alpha: 0.1)
                      : colors.surface,
                  border: Border.all(
                    color: isSelected ? colors.brand : colors.border,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  _paymentMethodLabel(language, method),
                  style: textStyles.smallSans.copyWith(
                    color: isSelected ? colors.brand : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
