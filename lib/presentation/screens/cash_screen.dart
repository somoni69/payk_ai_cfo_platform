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
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/ledger_collapsing_header.dart';
import '../widgets/expansible_widget.dart';

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

  String _selectedType = 'all';
  String _selectedPaymentMethod = 'all';
  String _selectedRegister = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshCash(BuildContext context) {
    final completion = Completer<void>();
    context.read<CashBloc>().add(LoadCashData(completion: completion));
    return completion.future;
  }

  void _showReportDownloadBottomSheet(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_download_report'),
      builder: (context, setSheetState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Выберите формат экспортного отчета или выгрузки:',
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Отчет Excel успешно экспортирован'),
                          ),
                        );
                      },
                      icon: Icon(
                        TablerIcons.file_spreadsheet,
                        color: colors.accentGreen,
                        size: 18,
                      ),
                      label: Text(language.translate('cash_export_excel')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Отчет PDF успешно экспортирован'),
                          ),
                        );
                      },
                      icon: Icon(
                        TablerIcons.file_text,
                        color: colors.accentRed,
                        size: 18,
                      ),
                      label: Text(language.translate('cash_export_pdf')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Окно импорта вызвано')),
                        );
                      },
                      icon: Icon(
                        TablerIcons.upload,
                        color: colors.brand,
                        size: 18,
                      ),
                      label: Text(language.translate('cash_import')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
          return Scaffold(
            floatingActionButton: !isViewer && _tabController.index == 0
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddTransactionBottomSheet(
                      context,
                      authState,
                      state.registers,
                    ),
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    icon: const Icon(TablerIcons.plus),
                    label: Text(
                      language.translate('cash_new_operation_btn'),
                      style: textStyles.bodySans.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : (!isViewer && _tabController.index == 1
                      ? FloatingActionButton.extended(
                          onPressed: () => _showOpenShiftBottomSheet(
                            context,
                            state.registers,
                          ),
                          backgroundColor: colors.brand,
                          foregroundColor: Colors.white,
                          icon: const Icon(TablerIcons.plus),
                          label: Text(
                            language.translate('cash_open_shift_btn'),
                            style: textStyles.bodySans.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  LedgerCollapsingHeader(
                    title: language.translate('cash_title'),
                    pinned: true,
                    floating: true,
                    snap: true,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showReportDownloadBottomSheet(context),
                        icon: const Icon(TablerIcons.download, size: 16),
                        label: Text(
                          language.translate('cash_download_report'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: colors.brand,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: colors.brand,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: colors.border,
                      labelStyle: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: [
                        Tab(text: language.translate('cash_tab_operations')),
                        Tab(text: language.translate('cash_tab_shifts')),
                        Tab(text: language.translate('cash_tab_summary')),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOperationsTab(context, state),
                  _buildShiftsTab(context, state, isViewer),
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

  Widget _buildOperationsTab(BuildContext context, CashLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

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
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: const ['all', 'income', 'expense'],
                        selectedValue: _selectedType,
                        itemLabelBuilder: (item) {
                          if (item == 'income')
                            return language.translate('cash_income');
                          if (item == 'expense')
                            return language.translate('cash_expense');
                          return language.translate('cash_filter_all_types');
                        },
                        onSelected: (val) {
                          setState(() => _selectedType = val);
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
                                    ? 'Наличные'
                                    : 'Карта'),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: const ['all', 'cash', 'card'],
                        selectedValue: _selectedPaymentMethod,
                        itemLabelBuilder: (item) {
                          if (item == 'cash') return 'Наличные';
                          if (item == 'card') return 'Карта';
                          return language.translate(
                            'cash_filter_all_payment_methods',
                          );
                        },
                        onSelected: (val) {
                          setState(() => _selectedPaymentMethod = val);
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
                                      orElse: () => const CashRegister(
                                        id: '',
                                        name: 'Касса',
                                      ),
                                    )
                                    .name),
                          style: textStyles.captionSans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: registerIds,
                        selectedValue: _selectedRegister,
                        itemLabelBuilder: (id) {
                          if (id == 'all')
                            return language.translate(
                              'cash_filter_all_registers',
                            );
                          final reg = state.registers.firstWhere(
                            (r) => r.id == id,
                            orElse: () => CashRegister(id: id, name: id),
                          );
                          return reg.name;
                        },
                        onSelected: (val) {
                          setState(() => _selectedRegister = val);
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

                return ExpansibleWidget(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tx.isIncome
                              ? colors.accentGreen.withValues(alpha: 0.1)
                              : colors.accentRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          tx.isIncome
                              ? TablerIcons.arrow_down_left
                              : TablerIcons.arrow_up_right,
                          color: tx.isIncome
                              ? colors.accentGreen
                              : colors.accentRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language.translateMessage(tx.title),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tx.category} • ${tx.paymentMethod.label}',
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${tx.isIncome ? '+' : '-'}${oCcy.format(tx.amount)} смн',
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.bold,
                              color: tx.isIncome
                                  ? colors.accentGreen
                                  : colors.accentRed,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatLocalizedDateTime(
                              context,
                              tx.dateTime,
                              style: LocalizedDateTimeStyle.dateTime,
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
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
                            'Кассир:',
                            tx.cashierName == 'Система'
                                ? 'Система'
                                : language.translateMessage(tx.cashierName),
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            context,
                            'Способ оплаты:',
                            tx.paymentMethod.label,
                          ),
                          const SizedBox(height: 6),
                          _buildDetailRow(context, 'Категория:', tx.category),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            context,
                            'Кассовый аппарат:',
                            tx.registerId != null
                                ? 'Касса #${tx.registerId}'
                                : 'Главная касса',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
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
    final oCcy = localizedDecimalFormat(context);

    if (state.shifts.isEmpty) {
      return Center(
        child: Text(
          'История смен пуста',
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
                        shift.registerName ?? 'Главная касса',
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Кассир: ${shift.cashierName ?? 'Директор'}',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                LedgerPill(
                  text: shift.isOpen ? 'Открыта' : 'Закрыта',
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
                      'Открыта:',
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
                        'Закрыта:',
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
                      'Начальный баланс:',
                      '${oCcy.format(shift.startingBalance)} смн',
                    ),
                    if (shift.endingBalance != null) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        context,
                        'Фактический баланс:',
                        '${oCcy.format(shift.endingBalance!)} смн',
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Расхождение:',
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          '${oCcy.format(diff)} смн',
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.bold,
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
                        fontWeight: FontWeight.bold,
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
                      '${oCcy.format(row.income)} смн',
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.bold,
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
                      '${oCcy.format(row.expense)} смн',
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Итого',
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${oCcy.format(row.net)} смн',
                      style: textStyles.h2Sans.copyWith(
                        color: isNegativeNet
                            ? colors.accentRed
                            : colors.accentGreen,
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

  /// Фирменная системная модалка "Открыть кассовую смену" (LedgerBottomSheet)
  void _showOpenShiftBottomSheet(
    BuildContext context,
    List<CashRegister> registers,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final controller = TextEditingController(text: '5000');
    String? selectedRegisterId = registers.isNotEmpty
        ? registers.first.id
        : null;

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_open_shift_title'),
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Укажите начальный баланс наличных в кассе для открытия смены.',
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            if (registers.isNotEmpty) ...[
              Text(
                language.translate('cash_register'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<String>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0,
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  registers
                      .firstWhere(
                        (r) => r.id == selectedRegisterId,
                        orElse: () =>
                            const CashRegister(id: '', name: 'Главная касса'),
                      )
                      .name,
                  style: textStyles.bodySans,
                ),
                items: registers.map((r) => r.id).toList(),
                selectedValue: selectedRegisterId,
                itemLabelBuilder: (id) => registers
                    .firstWhere(
                      (r) => r.id == id,
                      orElse: () => CashRegister(id: id, name: id),
                    )
                    .name,
                onSelected: (val) =>
                    setSheetState(() => selectedRegisterId = val),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              language.translate('cash_starting_balance_label'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodyMono.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  TablerIcons.cash,
                  color: colors.brand,
                  size: 20,
                ),
                suffixText: 'смн',
                hintText: '5 000',
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final bal = parseLocalizedNumber(context, controller.text);
                  if (bal != null && bal >= 0) {
                    context.read<CashBloc>().add(OpenShiftRequested(bal));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('cash_open_shift_action'),
                  style: textStyles.bodySans.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Точная исходная модалка "Новая операция" согласно скриншоту
  void _showAddTransactionBottomSheet(
    BuildContext context,
    AuthState authState,
    List<CashRegister> registers,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final formKey = GlobalKey<FormState>();

    bool isIncome = true; // По умолчанию выбран "Приход" как на скриншоте
    final amountController = TextEditingController();
    final counterpartyController = TextEditingController();
    final descriptionController = TextEditingController();
    PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
    String? selectedCategory;
    String? selectedRegisterId = registers.isNotEmpty
        ? registers.first.id
        : null;

    final categories = [
      'Зарплата',
      'Продажи',
      'Услуги',
      'Аванс',
      'Инвентарь',
      'Прочее',
    ];

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_new_operation'),
      builder: (context, setSheetState) {
        return Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Выбор "Приход" / "Расход" (Сегментный чип как на скриншоте)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setSheetState(() => isIncome = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isIncome
                              ? colors.accentGreen.withValues(alpha: 0.1)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isIncome
                                ? colors.accentGreen
                                : colors.border,
                            width: isIncome ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            language.translate('cash_income'),
                            style: textStyles.bodySans.copyWith(
                              color: isIncome
                                  ? colors.accentGreen
                                  : colors.textSecondary,
                              fontWeight: isIncome
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setSheetState(() => isIncome = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isIncome
                              ? colors.accentRed.withValues(alpha: 0.1)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isIncome ? colors.accentRed : colors.border,
                            width: !isIncome ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            language.translate('cash_expense'),
                            style: textStyles.bodySans.copyWith(
                              color: !isIncome
                                  ? colors.accentRed
                                  : colors.textSecondary,
                              fontWeight: !isIncome
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Касса (Заголовок + Наш фирменный ExpansibleWidget)
              if (registers.isNotEmpty) ...[
                Text(
                  language.translate('cash_register'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<String>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    registers
                        .firstWhere(
                          (r) => r.id == selectedRegisterId,
                          orElse: () =>
                              const CashRegister(id: '', name: 'Главная касса'),
                        )
                        .name,
                    style: textStyles.bodySans,
                  ),
                  items: registers.map((r) => r.id).toList(),
                  selectedValue: selectedRegisterId,
                  itemLabelBuilder: (id) => registers
                      .firstWhere(
                        (r) => r.id == id,
                        orElse: () => CashRegister(id: id, name: id),
                      )
                      .name,
                  onSelected: (val) =>
                      setSheetState(() => selectedRegisterId = val),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Сумма операции (Иконка доллара)
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  hintText: language.translate('cash_operation_amount'),
                  prefixIcon: Icon(
                    TablerIcons.currency_dollar,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
                validator: (val) {
                  final parsed = parseLocalizedNumber(context, val ?? '');
                  if (parsed == null || parsed <= 0) {
                    return language.translate('cash_amount_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 4. Способ оплаты (Чипы горизонтально)
              Text(
                language.translate('cash_payment_method'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: PaymentMethod.values.map((pm) {
                  final isSelected = selectedPaymentMethod == pm;
                  return ChoiceChip(
                    label: Text(pm.label),
                    selected: isSelected,
                    selectedColor: colors.brand.withValues(alpha: 0.12),
                    labelStyle: textStyles.captionSans.copyWith(
                      color: isSelected ? colors.brand : colors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? colors.brand : colors.border,
                    ),
                    onSelected: (val) {
                      if (val) setSheetState(() => selectedPaymentMethod = pm);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 5. Категория (Заголовок + Наш фирменный ExpansibleWidget)
              Text(
                language.translate('cash_category'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<String>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 0,
                ),
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  selectedCategory ??
                      language.translate('cash_select_category'),
                  style: textStyles.bodySans.copyWith(
                    color: selectedCategory != null
                        ? colors.textPrimary
                        : colors.textSecondary,
                  ),
                ),
                items: categories,
                selectedValue: selectedCategory,
                itemLabelBuilder: (category) => category,
                onSelected: (val) =>
                    setSheetState(() => selectedCategory = val),
              ),
              const SizedBox(height: 16),

              // 6. Контрагент (Иконка пользователя)
              TextFormField(
                controller: counterpartyController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  hintText: language.translate('cash_counterparty'),
                  prefixIcon: Icon(
                    TablerIcons.user,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return language.translate('cash_counterparty_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 7. Описание (Иконка документа)
              TextField(
                controller: descriptionController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  hintText: language.translate('cash_description'),
                  prefixIcon: Icon(
                    TablerIcons.file_text,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 8. Фирменная кнопка "Записать в Ledger"
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final amt = parseLocalizedNumber(
                      context,
                      amountController.text,
                    )!;

                    final tx = Transaction(
                      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                      title: counterpartyController.text.trim(),
                      category: selectedCategory ?? 'Прочее',
                      amount: amt,
                      isIncome: isIncome,
                      paymentMethod: selectedPaymentMethod,
                      dateTime: DateTime.now(),
                      registerId: selectedRegisterId,
                      cashierName: authState is AuthAuthenticated
                          ? authState.username
                          : 'Директор',
                    );

                    context.read<CashBloc>().add(AddTransactionRequested(tx));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    language.translate('save_to_ledger'),
                    style: textStyles.bodySans.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
