import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
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

/// Точка входа в кассовый модуль с внедрением CashBloc.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CashBloc>(
      create: (context) => CashBloc(context.read<CashRepository>())..add(LoadCashData()),
      child: const CashView(),
    );
  }
}

class CashView extends StatefulWidget {
  const CashView({super.key});

  @override
  State<CashView> createState() => _CashViewState();
}

class _CashViewState extends State<CashView> with SingleTickerProviderStateMixin {
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

  String _formatAmount(double amount) {
    final int val = amount.round();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return val.toString().replaceAllMapped(reg, (Match match) => '${match[1]} ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final authState = context.watch<AuthBloc>().state;
    final isViewer = authState is AuthAuthenticated && authState.role == UserRole.viewer;

    return BlocConsumer<CashBloc, CashState>(
      listener: (context, state) {
        if (state is CashLoaded && state.errorMessage != null) {
          // Показ оповещений (об ошибках или результате закрытия смены)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage!,
                style: textStyles.bodySans.copyWith(color: colors.surface),
              ),
              backgroundColor: state.errorMessage!.contains('Внимание') || state.errorMessage!.contains('Ошибка')
                  ? colors.accentRed
                  : (state.errorMessage!.contains('успешно') ? colors.accentGreen : colors.textPrimary),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is CashLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
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
                    Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 40),
                    const SizedBox(height: 12),
                    Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<CashBloc>().add(LoadCashData());
                      },
                      child: const Text('Повторить попытку'),
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
            appBar: AppBar(
              backgroundColor: colors.surface,
              scrolledUnderElevation: 0,
              title: Text('Касса и операции', style: textStyles.h1Sans),
              actions: [
                if (!isViewer && isShiftOpen) ...[
                  IconButton(
                    icon: const Icon(TablerIcons.plus),
                    onPressed: () => _showAddTransactionBottomSheet(context, authState, state.registers),
                    tooltip: 'Добавить операцию',
                  ),
                  const SizedBox(width: 8),
                ],
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                indicatorColor: colors.brand,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: colors.border,
                labelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w500),
                unselectedLabelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Операции'),
                  Tab(text: 'Кассовые аппараты'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    // Панель статуса смены (CASH-05 / CASH-06)
                    _buildShiftStatusBanner(context, state.activeShift, isViewer),
                    const Divider(),

                    // Поиск и Фильтры
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: TextField(
                                controller: _searchController,
                                style: textStyles.bodySans,
                                onChanged: (val) {
                                  context.read<CashBloc>().add(SearchFilterChanged(
                                        query: val,
                                        filterType: state.filterType,
                                      ));
                                },
                                decoration: InputDecoration(
                                  hintText: 'Поиск по получателю или категории...',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  prefixIcon: Icon(TablerIcons.search, size: 18, color: colors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(context, 'Все', 'all', state.query, state.filterType),
                          const SizedBox(width: 4),
                          _buildFilterChip(context, 'Приход', 'income', state.query, state.filterType),
                          const SizedBox(width: 4),
                          _buildFilterChip(context, 'Расход', 'expense', state.query, state.filterType),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Список операций
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          context.read<CashBloc>().add(LoadCashData());
                        },
                        child: state.filteredTransactions.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: Text(
                                        'Операции не найдены',
                                        style: textStyles.captionSans.copyWith(color: colors.textTooltip),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                itemCount: state.filteredTransactions.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final tx = state.filteredTransactions[index];

                                  return LedgerOperationRow(
                                    title: tx.title,
                                    category: '${tx.category} • ${tx.paymentMethod.label}',
                                    amount: '${tx.isIncome ? "+" : "-"}${_formatAmount(tx.amount)} TJS',
                                    isIncome: tx.isIncome,
                                    pillText: tx.cashierName,
                                    pillColor: colors.brand.withValues(alpha: 0.1),
                                    pillTextColor: colors.brand,
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
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildShiftStatusBanner(BuildContext context, CashShift? activeShift, bool isViewer) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isOpen = activeShift != null;

    return Container(
      color: isOpen ? colors.accentGreen.withValues(alpha: 0.05) : colors.accentRed.withValues(alpha: 0.05),
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
                  isOpen ? 'Кассовая смена открыта' : 'Кассовая смена закрыта',
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isOpen ? colors.accentGreen : colors.accentRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOpen
                      ? 'Начало: ${DateFormat('HH:mm').format(activeShift.openedAt)} • Баланс: ${_formatAmount(activeShift.startingBalance)} TJS'
                      : 'Проведение операций временно заблокировано',
                  style: textStyles.smallSans.copyWith(color: colors.textSecondary),
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
                side: BorderSide(color: isOpen ? colors.accentRed.withValues(alpha: 0.5) : colors.accentGreen.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(isOpen ? 'Закрыть' : 'Открыть'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String type, String currentQuery, String currentFilterType) {
    final isSelected = currentFilterType == type;
    final colors = context.colors;
    final textStyles = context.textStyles;

    return GestureDetector(
      onTap: () {
        context.read<CashBloc>().add(SearchFilterChanged(
              query: currentQuery,
              filterType: type,
            ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? colors.brand : colors.surface,
          border: Border.all(color: isSelected ? colors.brand : colors.border),
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
    );
  }

  void _showOpenShiftDialog(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final controller = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          title: Text('Открыть кассовую смену', style: textStyles.h2Sans),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: textStyles.bodyMono,
            decoration: const InputDecoration(
              labelText: 'Начальный баланс кассы (TJS)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? bal = double.tryParse(controller.text);
                if (bal != null) {
                  context.read<CashBloc>().add(OpenShiftRequested(bal));
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Открыть смену'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseShiftDialog(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          title: Text('Закрыть кассовую смену', style: textStyles.h2Sans),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Перед закрытием пересчитайте фактический баланс в физическом ящике кассы.',
                style: textStyles.captionSans,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: textStyles.bodyMono,
                decoration: const InputDecoration(
                  labelText: 'Фактический остаток в кассе (TJS)',
                  hintText: 'Укажите пересчитанную сумму',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? bal = double.tryParse(controller.text);
                if (bal != null) {
                  context.read<CashBloc>().add(CloseShiftRequested(bal));
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Закрыть смену'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryTab(BuildContext context, List<CashSummary> summaries) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    if (summaries.isEmpty) {
      return Center(
        child: Text(
          'Сводка кассовых аппаратов пуста',
          style: textStyles.captionSans.copyWith(color: colors.textTooltip),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CashBloc>().add(LoadCashData());
      },
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
                      row.registerName,
                      style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (row.hasOpenShift)
                      LedgerPill(
                        text: 'СМЕНА ОТКРЫТА',
                        backgroundColor: colors.accentGreen.withValues(alpha: 0.1),
                        textColor: colors.accentGreen,
                      )
                    else
                      LedgerPill(
                        text: 'СМЕНА ЗАКРЫТА',
                        backgroundColor: colors.textSecondary.withValues(alpha: 0.1),
                        textColor: colors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Приход:', style: textStyles.smallSans.copyWith(color: colors.textSecondary)),
                    Text(
                      '${oCcy.format(row.income)} TJS',
                      style: textStyles.bodyMono.copyWith(color: colors.accentGreen, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Расход:', style: textStyles.smallSans.copyWith(color: colors.textSecondary)),
                    Text(
                      '${oCcy.format(row.expense)} TJS',
                      style: textStyles.bodyMono.copyWith(color: colors.accentRed, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Чистый поток:', style: textStyles.smallSans.copyWith(fontWeight: FontWeight.w500)),
                    Text(
                      '${row.net >= 0 ? "+" : ""}${oCcy.format(row.net)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        color: row.net >= 0 ? colors.accentGreen : colors.accentRed,
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

  void _showAddTransactionBottomSheet(BuildContext context, AuthState authState, List<CashRegister> registers) {
    final cashBloc = context.read<CashBloc>();
    LedgerBottomSheet.show(
      context: context,
      title: 'Новая операция',
      builder: (context, setSheetState) {
        return _AddTransactionBottomSheet(
          cashBloc: cashBloc,
          authState: authState,
          registers: registers,
        );
      },
    );
  }
}

class _AddTransactionBottomSheet extends StatefulWidget {
  final CashBloc cashBloc;
  final AuthState authState;
  final List<CashRegister> registers;

  const _AddTransactionBottomSheet({
    required this.cashBloc,
    required this.authState,
    required this.registers,
  });

  @override
  State<_AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends State<_AddTransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isIncome = true;
  String _paymentMethodLabel = 'Наличные';
  String _selectedRegisterId = '';
  String _selectedCategory = '';

  final _incomeCategories = const ['sales', 'services', 'advance', 'refund_in', 'other_income'];
  final _expenseCategories = const ['rent', 'salary', 'goods', 'utilities', 'marketing', 'transport', 'taxes', 'other_expense'];

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.registers.isNotEmpty) {
      _selectedRegisterId = widget.registers[0].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getCategoryLabel(String key) {
    switch (key) {
      case 'sales': return 'Продажи';
      case 'services': return 'Услуги';
      case 'advance': return 'Аванс';
      case 'refund_in': return 'Возврат';
      case 'other_income': return 'Прочий доход';
      case 'rent': return 'Аренда';
      case 'salary': return 'Зарплата';
      case 'goods': return 'Товары';
      case 'utilities': return 'Коммунальные';
      case 'marketing': return 'Реклама';
      case 'transport': return 'Транспорт';
      case 'taxes': return 'Налоги';
      case 'other_expense': return 'Прочий расход';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Переключатель Приход / Расход
          Row(
            children: [
              Expanded(
                child: _buildTypeButton('Приход', true, colors.accentGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTypeButton('Расход', false, colors.accentRed),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Касса (Register)
          if (widget.registers.isNotEmpty) ...[
            Text('Касса', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ExpansibleWidget<String>.selection(
              key: ValueKey('reg_$_selectedRegisterId'),
              cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(
                widget.registers.firstWhere((r) => r.id == _selectedRegisterId, orElse: () => widget.registers[0]).name,
                style: textStyles.bodySans,
              ),
              items: widget.registers.map((r) => r.id).toList(),
              selectedValue: _selectedRegisterId,
              itemLabelBuilder: (id) => widget.registers.firstWhere((r) => r.id == id).name,
              onSelected: (val) {
                setState(() {
                  _selectedRegisterId = val;
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // Поле Сумма
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.w500),
            validator: (val) => val == null || val.trim().isEmpty ? 'Укажите сумму' : null,
            decoration: InputDecoration(
              labelText: 'Сумма операции',
              hintText: '0.00 TJS',
              prefixIcon: Icon(TablerIcons.coin, color: colors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Способ оплаты
          Text('Способ оплаты', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildPaymentMethodsRow(),
          const SizedBox(height: 16),

          // Категория
          Text('Категория', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ExpansibleWidget<String>.selection(
            key: ValueKey('cat_${_isIncome}_$_selectedCategory'),
            cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(
              _selectedCategory.isEmpty
                  ? 'Выберите категорию'
                  : _getCategoryLabel(_selectedCategory),
              style: textStyles.bodySans,
            ),
            items: _isIncome ? _incomeCategories : _expenseCategories,
            selectedValue: _selectedCategory,
            itemLabelBuilder: (cat) => _getCategoryLabel(cat),
            onSelected: (val) {
              setState(() {
                _selectedCategory = val;
              });
            },
          ),
          const SizedBox(height: 12),

          // Поле Получатель / Контрагент
          TextFormField(
            controller: _titleController,
            style: textStyles.bodySans,
            validator: (val) => val == null || val.trim().isEmpty ? 'Введите наименование' : null,
            decoration: InputDecoration(
              labelText: 'Контрагент',
              hintText: 'Название контрагента',
              prefixIcon: Icon(TablerIcons.user, color: colors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Описание
          TextFormField(
            controller: _descriptionController,
            style: textStyles.bodySans,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Описание',
              hintText: 'Комментарий к операции',
              prefixIcon: Icon(TablerIcons.notes, color: colors.textSecondary, size: 20),
            ),
          ),
          const SizedBox(height: 24),

          // Кнопки
          ElevatedButton(
            onPressed: () {
              if (_selectedCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Пожалуйста, выберите категорию'),
                    backgroundColor: colors.accentRed,
                  ),
                );
                return;
              }
              if (_formKey.currentState!.validate()) {
                final double? amount = double.tryParse(_amountController.text);
                if (amount != null) {
                  // Вычисляем имя кассира
                  String cashierName = 'Система';
                  if (widget.authState is AuthAuthenticated) {
                    cashierName = (widget.authState as AuthAuthenticated).username;
                  }

                  final newTx = Transaction(
                    id: '',
                    title: _titleController.text.trim(),
                    category: _selectedCategory,
                    amount: amount,
                    isIncome: _isIncome,
                    paymentMethod: PaymentMethod.fromLabel(_paymentMethodLabel),
                    dateTime: DateTime.now(),
                    cashierName: cashierName,
                    registerId: _selectedRegisterId.isNotEmpty ? _selectedRegisterId : null,
                  );

                  widget.cashBloc.add(AddTransactionRequested(newTx));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Записать в Ledger'),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, bool isIncomeType, Color activeColor) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isSelected = _isIncome == isIncomeType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isIncome = isIncomeType;
        });
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.1) : colors.surface,
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
    );
  }

  Widget _buildPaymentMethodsRow() {
    final methods = ['Наличные', 'Карта', 'Алиф', 'Душанбе Сити', 'ОСМС'];
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: methods.map((m) {
        final isSelected = _paymentMethodLabel == m;
        return GestureDetector(
          onTap: () {
            setState(() {
              _paymentMethodLabel = m;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? colors.brand.withValues(alpha: 0.1) : colors.surface,
              border: Border.all(
                color: isSelected ? colors.brand : colors.border,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              m,
              style: textStyles.smallSans.copyWith(
                color: isSelected ? colors.brand : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
