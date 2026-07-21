import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/localization/locale_number_format.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/language_cubit.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/warehouse/bloc/warehouse_bloc.dart';
import '../../features/warehouse/bloc/warehouse_event.dart';
import '../../features/warehouse/bloc/warehouse_state.dart';
import '../../features/warehouse/domain/warehouse_models.dart';
import '../../features/warehouse/domain/warehouse_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/ledger_collapsing_header.dart';

class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();

    return BlocProvider<WarehouseBloc>(
      create: (context) =>
          WarehouseBloc(context.read<WarehouseRepository>())
            ..add(LoadWarehouseData()),
      child: const WarehouseView(),
    );
  }
}

class WarehouseView extends StatefulWidget {
  const WarehouseView({super.key});

  @override
  State<WarehouseView> createState() => _WarehouseViewState();
}

class _WarehouseViewState extends State<WarehouseView>
    with SingleTickerProviderStateMixin {
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
    final localeCubit = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.warehouse);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: localeCubit.translate('warehouse_title'),
              pinned: true,
              floating: true,
              snap: true,
              actions: [
                if (canManage)
                  IconButton(
                    icon: const Icon(TablerIcons.plus),
                    tooltip: localeCubit.translate('warehouse_add_product_title'),
                    color: colors.brand,
                    onPressed: () => _showAddProductDialog(context),
                  ),
                if (canManage)
                  IconButton(
                    icon: const Icon(TablerIcons.arrow_left_right),
                    tooltip: localeCubit.translate('warehouse_movement_title'),
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
          ];
        },
        body: BlocListener<WarehouseBloc, WarehouseState>(
        listener: (context, state) {
          if (state is WarehouseLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(state.errorMessage!),
                  ),
                  backgroundColor: colors.accentRed,
                ),
              );
            } else if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(state.successMessage!),
                  ),
                  backgroundColor: colors.accentGreen,
                ),
              );
            }
          }
        },
        child: BlocBuilder<WarehouseBloc, WarehouseState>(
          buildWhen: (previous, current) {
            if (previous is WarehouseLoaded && current is WarehouseLoaded) {
              return previous.products != current.products ||
                  previous.movements != current.movements ||
                  previous.summary != current.summary;
            }
            return previous.runtimeType != current.runtimeType ||
                previous != current;
          },
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
                      Icon(
                        TablerIcons.alert_circle,
                        size: 48,
                        color: colors.accentRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localeCubit.translateMessage(state.message),
                        style: textStyles.bodySans,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<WarehouseBloc>().add(
                          LoadWarehouseData(),
                        ),
                        child: Text(localeCubit.translate('common_retry')),
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
    ),
  );
  }

  Widget _buildProductsTab(BuildContext context, WarehouseLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: context.read<WarehouseBloc>().reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.products.isEmpty ? 2 : state.products.length + 1,
        separatorBuilder: (context, index) =>
            SizedBox(height: index == 0 ? 16 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Сводные метрики склада
            return Row(
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
                          style: textStyles.smallSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${state.summary.productsCount}',
                            style: textStyles.h1Mono.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
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
                          style: textStyles.smallSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            localeCubit.translate(
                              'warehouse_amount_tjs',
                              params: {
                                'amount': oCcy.format(
                                  state.summary.totalStockValue,
                                ),
                              },
                            ),
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
            );
          }

          if (state.products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64.0),
                child: Text(
                  localeCubit.translate('warehouse_empty_products'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            );
          }

          final product = state.products[index - 1];
          return LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localeCubit.translateMessage(product.name),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (product.sku != null && product.sku!.isNotEmpty)
                      Text(
                        localeCubit.translate(
                          'warehouse_product_sku',
                          params: {'sku': product.sku},
                        ),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      localeCubit.translate(
                        'warehouse_product_price',
                        params: {'price': oCcy.format(product.price)},
                      ),
                      style: textStyles.smallMono.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LedgerPill(
                      text: localeCubit.translate(
                        'warehouse_quantity_with_unit',
                        params: {
                          'quantity': formatLocalizedNumber(
                            context,
                            product.stockQty,
                          ),
                          'unit': localeCubit.translateMessage(product.unit),
                        },
                      ),
                      backgroundColor: product.stockQty > 0
                          ? colors.brand.withValues(alpha: 0.08)
                          : colors.accentRed.withValues(alpha: 0.08),
                      textColor: product.stockQty > 0
                          ? colors.brand
                          : colors.accentRed,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localeCubit.translate(
                        'warehouse_amount_tjs',
                        params: {
                          'amount': oCcy.format(
                            product.stockQty * product.price,
                          ),
                        },
                      ),
                      style: textStyles.smallMono.copyWith(
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

  Widget _buildMovementsTab(BuildContext context, WarehouseLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final dtFmt = DateFormat("dd.MM.yyyy HH:mm");

    return RefreshIndicator(
      onRefresh: context.read<WarehouseBloc>().reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.movements.isEmpty ? 1 : state.movements.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (state.movements.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64.0),
                child: Text(
                  localeCubit.translate('warehouse_empty_movements'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            );
          }

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
                    Text(
                      localeCubit.translateMessage(m.productName),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      dtFmt.format(m.occurredAt.toLocal()),
                      style: textStyles.smallSans.copyWith(
                        color: colors.textTooltip,
                      ),
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
                          isIncome
                              ? TablerIcons.arrow_down_left
                              : TablerIcons.arrow_up_right,
                          size: 16,
                          color: isIncome
                              ? colors.accentGreen
                              : colors.accentRed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIncome
                              ? localeCubit.translate(
                                  'warehouse_movement_income',
                                )
                              : localeCubit.translate(
                                  'warehouse_movement_expense',
                                ),
                          style: textStyles.smallSans.copyWith(
                            color: isIncome
                                ? colors.accentGreen
                                : colors.accentRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          localeCubit.translate(
                            'warehouse_movement_quantity',
                            params: {
                              'sign': isIncome ? '+' : '-',
                              'quantity': formatLocalizedNumber(context, m.qty),
                            },
                          ),
                          style: textStyles.smallMono.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isIncome
                                ? colors.accentGreen
                                : colors.accentRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          localeCubit.translate(
                            'warehouse_amount_tjs',
                            params: {'amount': oCcy.format(m.amount)},
                          ),
                          style: textStyles.smallMono.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (m.note != null && m.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    localeCubit.translateMessage(m.note!),
                    style: textStyles.smallSans.copyWith(
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddProductDialog(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final unitController = TextEditingController(
      text: language.translate('warehouse_unit_pieces_short'),
    );
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '0');

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('warehouse_add_product_title'),
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_product_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuController,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_product_sku_label'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: language.translate('warehouse_unit_label'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: language.translate('warehouse_price_label'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_initial_stock'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price =
                  parseLocalizedNumber(context, priceController.text) ?? 0.0;
              final stock =
                  parseLocalizedNumber(context, stockController.text) ?? 0.0;

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
              Navigator.pop(context);
            },
            child: Text(language.translate('common_create')),
          );
        },
      );
    } finally {
      nameController.dispose();
      skuController.dispose();
      unitController.dispose();
      priceController.dispose();
      stockController.dispose();
    }
  }

  Widget _buildMovementTypeButton(
    BuildContext context,
    String label,
    String type,
    Color activeColor,
    String currentType,
    ValueChanged<String> onChanged,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isSelected = currentType == type;

    return GestureDetector(
      onTap: () => onChanged(type),
      child: Container(
        height: 48,
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
    );
  }

  Future<void> _showAddMovementDialog(BuildContext context) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final warehouseBloc = context.read<WarehouseBloc>();
    final state = warehouseBloc.state;
    if (state is! WarehouseLoaded) return;

    String productOptionLabel(WarehouseProduct product) {
      return language.translate(
        'warehouse_product_with_stock',
        params: {
          'name': language.translateMessage(product.name),
          'stock': formatLocalizedNumber(context, product.stockQty),
        },
      );
    }

    WarehouseProduct? selectedProduct = state.products.isNotEmpty
        ? state.products.first
        : null;
    String direction = 'income';
    final qtyController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('warehouse_movement_title'),
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Переключатель направления движения
              Row(
                children: [
                  Expanded(
                    child: _buildMovementTypeButton(
                      context,
                      language.translate('warehouse_movement_purchase'),
                      'income',
                      colors.accentGreen,
                      direction,
                      (val) {
                        setSheetState(() {
                          direction = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMovementTypeButton(
                      context,
                      language.translate('warehouse_movement_sale'),
                      'expense',
                      colors.accentRed,
                      direction,
                      (val) {
                        setSheetState(() {
                          direction = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Товар
              Text(
                language.translate('warehouse_product'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ExpansibleWidget<WarehouseProduct?>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  selectedProduct == null
                      ? language.translate('warehouse_select_product')
                      : productOptionLabel(selectedProduct!),
                  style: textStyles.bodySans,
                ),
                items: state.products,
                selectedValue: selectedProduct,
                itemLabelBuilder: (p) => p == null ? '' : productOptionLabel(p),
                onSelected: (p) {
                  setSheetState(() {
                    selectedProduct = p;
                  });
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: language.translate(
                          'warehouse_quantity_label',
                        ),
                        hintText: language.translate('warehouse_quantity_hint'),
                      ),
                      onChanged: (val) {
                        final qty = parseLocalizedNumber(context, val) ?? 0.0;
                        final price = selectedProduct?.price ?? 0.0;
                        amountController.text = formatLocalizedNumber(
                          context,
                          qty * price,
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                          useGrouping: false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: language.translate(
                          'warehouse_optional_amount_label',
                        ),
                        hintText: language.translate('warehouse_amount_hint'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_note_label'),
                  hintText: language.translate('warehouse_note_hint'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: () {
              final qty =
                  parseLocalizedNumber(context, qtyController.text) ?? 0.0;
              final amount =
                  parseLocalizedNumber(context, amountController.text) ?? 0.0;
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
              Navigator.pop(context);
            },
            child: Text(language.translate('warehouse_record')),
          );
        },
      );
    } finally {
      qtyController.dispose();
      amountController.dispose();
      noteController.dispose();
    }
  }
}
