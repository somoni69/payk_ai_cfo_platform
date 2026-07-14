import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/language_cubit.dart';
import '../../features/warehouse/bloc/warehouse_bloc.dart';
import '../../features/warehouse/bloc/warehouse_event.dart';
import '../../features/warehouse/bloc/warehouse_state.dart';
import '../../features/warehouse/domain/warehouse_models.dart';
import '../../features/warehouse/domain/warehouse_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/expansible_widget.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WarehouseBloc>(
      create: (context) => WarehouseBloc(context.read<WarehouseRepository>())..add(LoadWarehouseData()),
      child: const WarehouseView(),
    );
  }
}

class WarehouseView extends StatefulWidget {
  const WarehouseView({super.key});

  @override
  State<WarehouseView> createState() => _WarehouseViewState();
}

class _WarehouseViewState extends State<WarehouseView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          localeCubit.translate('warehouse_title'),
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(TablerIcons.plus),
            color: colors.brand,
            onPressed: () => _showAddProductDialog(context),
          ),
          IconButton(
            icon: const Icon(TablerIcons.arrow_left_right),
            color: colors.brand,
            onPressed: () => _showAddMovementDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.brand,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: localeCubit.translate('warehouse_tab_products')),
            Tab(text: localeCubit.translate('warehouse_tab_movements')),
          ],
        ),
      ),
      body: BlocListener<WarehouseBloc, WarehouseState>(
        listener: (context, state) {
          if (state is WarehouseLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: colors.accentRed,
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: colors.accentGreen,
                ),
              );
            }
          }
        },
        child: BlocBuilder<WarehouseBloc, WarehouseState>(
          builder: (context, state) {
            if (state is WarehouseLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is WarehouseError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(TablerIcons.alert_circle, size: 48, color: colors.accentRed),
                      const SizedBox(height: 16),
                      Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<WarehouseBloc>().add(LoadWarehouseData()),
                        child: const Text('Повторить попытку'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is WarehouseLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsTab(context, state),
                  _buildMovementsTab(context, state),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, WarehouseLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = NumberFormat("#,##0.00", "ru_RU");

    return RefreshIndicator(
      onRefresh: () async {
        context.read<WarehouseBloc>().add(LoadWarehouseData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Сводные метрики склада
          Row(
            children: [
              Expanded(
                flex: 2,
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translate('warehouse_stats_count'),
                        style: textStyles.smallSans.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${state.summary.productsCount}',
                          style: textStyles.h1Mono.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translate('warehouse_stats_value'),
                        style: textStyles.smallSans.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${oCcy.format(state.summary.totalStockValue)} TJS',
                          style: textStyles.h1Mono.copyWith(
                            color: colors.accentGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (state.products.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64.0),
                child: Text(
                  localeCubit.translate('warehouse_empty_products'),
                  style: textStyles.bodySans.copyWith(color: colors.textTooltip),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = state.products[index];
                return LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          if (product.sku != null && product.sku!.isNotEmpty)
                            Text(
                              'SKU: ${product.sku}',
                              style: textStyles.smallSans.copyWith(color: colors.textSecondary),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '${localeCubit.translate('price')}: ${oCcy.format(product.price)} TJS',
                            style: textStyles.smallMono.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          LedgerPill(
                            text: '${product.stockQty % 1 == 0 ? product.stockQty.toInt() : product.stockQty} ${product.unit}',
                            backgroundColor: product.stockQty > 0 ? colors.brand.withValues(alpha: 0.08) : colors.accentRed.withValues(alpha: 0.08),
                            textColor: product.stockQty > 0 ? colors.brand : colors.accentRed,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${oCcy.format(product.stockQty * product.price)} TJS',
                            style: textStyles.smallMono.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMovementsTab(BuildContext context, WarehouseLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = NumberFormat("#,##0.00", "ru_RU");
    final dtFmt = DateFormat("dd.MM.yyyy HH:mm");

    return RefreshIndicator(
      onRefresh: () async {
        context.read<WarehouseBloc>().add(LoadWarehouseData());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.movements.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64.0),
                child: Text(
                  localeCubit.translate('warehouse_empty_movements'),
                  style: textStyles.bodySans.copyWith(color: colors.textTooltip),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.movements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final m = state.movements[index];
                final isIncome = m.direction == 'income';

                return LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.productName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                          Text(
                            dtFmt.format(m.occurredAt.toLocal()),
                            style: textStyles.smallSans.copyWith(color: colors.textTooltip),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isIncome ? TablerIcons.arrow_down_left : TablerIcons.arrow_up_right,
                                size: 16,
                                color: isIncome ? colors.accentGreen : colors.accentRed,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isIncome ? localeCubit.translate('income') : localeCubit.translate('expense'),
                                style: textStyles.smallSans.copyWith(
                                  color: isIncome ? colors.accentGreen : colors.accentRed,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${isIncome ? "+" : "-"}${m.qty} шт',
                                style: textStyles.smallMono.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: isIncome ? colors.accentGreen : colors.accentRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${oCcy.format(m.amount)} TJS',
                                style: textStyles.smallMono.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (m.note != null && m.note!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          m.note!,
                          style: textStyles.smallSans.copyWith(color: colors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    final colors = context.colors;
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final unitController = TextEditingController(text: 'шт');
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Добавить новый товар'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Название товара'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuController,
                  decoration: const InputDecoration(labelText: 'SKU (Артикул)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Ед. измерения'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Цена (TJS)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Начальный остаток'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text) ?? 0.0;
                final stock = double.tryParse(stockController.text) ?? 0.0;

                if (name.isEmpty) return;

                context.read<WarehouseBloc>().add(
                      CreateProductRequested(
                        WarehouseProduct(
                          id: '',
                          name: name,
                          sku: skuController.text.trim(),
                          unit: unitController.text.trim(),
                          price: price,
                          stockQty: stock,
                        ),
                      ),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );
  }

  void _showAddMovementDialog(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final warehouseBloc = context.read<WarehouseBloc>();
    final state = warehouseBloc.state;
    if (state is! WarehouseLoaded) return;

    WarehouseProduct? selectedProduct = state.products.isNotEmpty ? state.products.first : null;
    String direction = 'income';
    final qtyController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Движение товара'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExpansibleWidget(
                      key: ValueKey(selectedProduct?.id ?? 'empty'),
                      cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(
                        selectedProduct == null
                            ? 'Выберите товар'
                            : '${selectedProduct!.name} (остаток: ${selectedProduct!.stockQty % 1 == 0 ? selectedProduct!.stockQty.toInt() : selectedProduct!.stockQty})',
                        style: textStyles.bodySans,
                      ),
                      children: state.products.map((p) {
                        return ListTile(
                          title: Text('${p.name} (остаток: ${p.stockQty % 1 == 0 ? p.stockQty.toInt() : p.stockQty})', style: textStyles.bodySans),
                          onTap: () {
                            setState(() {
                              selectedProduct = p;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    ExpansibleWidget(
                      key: ValueKey(direction),
                      cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(
                        direction == 'income' ? 'Приход (поступление)' : 'Расход (продажа/списание)',
                        style: textStyles.bodySans,
                      ),
                      children: [
                        ListTile(
                          title: const Text('Приход (поступление)'),
                          onTap: () {
                            setState(() {
                              direction = 'income';
                            });
                          },
                        ),
                        ListTile(
                          title: const Text('Расход (продажа/списание)'),
                          onTap: () {
                            setState(() {
                              direction = 'expense';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Количество'),
                            onChanged: (val) {
                              // Автоматический подсчет ориентировочной суммы по цене товара
                              final qty = double.tryParse(val) ?? 0.0;
                              final price = selectedProduct?.price ?? 0.0;
                              amountController.text = (qty * price).toStringAsFixed(2);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Сумма (TJS)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Примечание'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyController.text) ?? 0.0;
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    final prodId = selectedProduct?.id;

                    if (qty <= 0 || prodId == null) return;

                    warehouseBloc.add(
                      CreateMovementRequested(
                        productId: prodId,
                        direction: direction,
                        qty: qty,
                        amount: amount,
                        note: noteController.text.trim(),
                      ),
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Записать'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
