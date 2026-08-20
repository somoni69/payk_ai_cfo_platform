import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/warehouse/bloc/warehouse_bloc.dart';
import '../../../features/warehouse/bloc/warehouse_event.dart';
import '../../../features/warehouse/bloc/warehouse_state.dart';
import '../../../features/warehouse/domain/warehouse_models.dart';
import '../../../features/warehouse/domain/warehouse_repository.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../assistant/presentation/ledger_advice_panel.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  var _activated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_activated || !TickerMode.valuesOf(context).enabled) return;
    _activated = true;
    context.read<WarehouseBloc>().add(LoadWarehouseData());
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    if (!_activated && !TickerMode.valuesOf(context).enabled) {
      return const SizedBox.shrink();
    }
    try {
      context.read<WarehouseBloc>();
      return const WarehouseView();
    } catch (_) {
      return BlocProvider<WarehouseBloc>(
        create: (context) =>
            WarehouseBloc(context.read<WarehouseRepository>())
              ..add(LoadWarehouseData()),
        child: const WarehouseView(),
      );
    }
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
  var _askedStockAnalysis = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
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
      floatingActionButton: canManage && _tabController.index < 3
          ? switch (_tabController.index) {
              0 => FloatingActionButton.extended(
                onPressed: () => _showAddProductDialog(context),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.plus),
                label: Text(
                  localeCubit.translate('warehouse_add_product_btn'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              1 => FloatingActionButton.extended(
                onPressed: () => _showAddMovementDialog(context),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.arrow_left_right),
                label: Text(
                  localeCubit.translate('warehouse_movement_btn'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _ => FloatingActionButton.extended(
                onPressed: () => _showAddBatchDialog(context),
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                highlightElevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.layers_linked),
                label: Text(
                  localeCubit.translate('warehouse_add_batch_btn'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            }
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: localeCubit.translate('warehouse_title'),
              pinned: true,
              floating: false,
              snap: false,
              bottom: LedgerTabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: localeCubit.translate('warehouse_tab_products')),
                  Tab(text: localeCubit.translate('warehouse_tab_movements')),
                  Tab(text: localeCubit.translate('warehouse_tab_batches')),
                  Tab(text: localeCubit.translate('warehouse_tab_analysis')),
                ],
              ),
              actions: canManage
                  ? [
                      IconButton(
                        tooltip: localeCubit.translate(
                          'warehouse_expiry_check_tooltip',
                        ),
                        onPressed: () {
                          context.read<WarehouseBloc>().add(
                            const RunExpiryCheckRequested(),
                          );
                        },
                        icon: Icon(
                          TablerIcons.alert_triangle,
                          color: colors.accentAmber,
                        ),
                      ),
                    ]
                  : null,
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
                final raw = state.successMessage!;
                final parts = raw.split('|');
                final text = parts.length == 2
                    ? localeCubit.translate(
                        parts[0],
                        params: {'count': parts[1]},
                      )
                    : localeCubit.translateMessage(raw);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(text),
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
                    previous.batches != current.batches ||
                    previous.batchesExpiringOnly !=
                        current.batchesExpiringOnly ||
                    previous.stockAnalysis != current.stockAnalysis ||
                    previous.isAnalysisLoading != current.isAnalysisLoading ||
                    previous.analysisError != current.analysisError ||
                    previous.summary != current.summary;
              }
              return previous.runtimeType != current.runtimeType ||
                  previous != current;
            },
            builder: (context, state) {
              if (state is WarehouseLoading) {
                return const WarehouseOverviewShimmer();
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
                    _buildBatchesTab(context, state, canManage: canManage),
                    _buildAnalysisTab(context, state),
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

  Widget _buildWarehouseAttention(BuildContext context, WarehouseLoaded state) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final analysis = state.stockAnalysis;
    if (analysis == null) {
      return const SizedBox.shrink();
    }
    final low = analysis.lowStock.length;
    final risk = analysis.expiringCount + analysis.expiredCount;
    final hasRisk = low > 0 || risk > 0;
    return LedgerCard(
      borderColor: hasRisk ? colors.accentAmber : colors.border,
      onTap: () => _tabController.animateTo(3),
      child: Row(
        children: [
          Icon(
            hasRisk ? TablerIcons.alert_triangle : TablerIcons.circle_check,
            color: hasRisk ? colors.accentAmber : colors.accentGreen,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.translate('warehouse_attention_title'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasRisk
                      ? language.translate(
                          'warehouse_attention_risk',
                          params: {'low': low, 'expiring': risk},
                        )
                      : language.translate('warehouse_attention_ok'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(TablerIcons.chevron_right, size: 18, color: colors.textTooltip),
        ],
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
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + kLiquidNavClearance,
        ),
        itemCount: state.products.isEmpty ? 2 : state.products.length + 1,
        separatorBuilder: (context, index) =>
            SizedBox(height: index == 0 ? 16 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            if (!_askedStockAnalysis &&
                state.stockAnalysis == null &&
                !state.isAnalysisLoading &&
                state.analysisError == null) {
              _askedStockAnalysis = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                context.read<WarehouseBloc>().add(
                  const RunStockAnalysisRequested(),
                );
              });
            }
            // Сводные метрики склада
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWarehouseAttention(context, state),
                const SizedBox(height: 12),
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
                                style: textStyles.h1Sans.copyWith(
                                  fontWeight: FontWeight.w600,
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
                                style: textStyles.h1Sans.copyWith(
                                  color: colors.accentGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
          final auth = context.watch<AuthBloc>().state;
          final canWrite =
              auth is AuthAuthenticated &&
              auth.role.canWrite(AppCapability.warehouse);
          return LedgerCard(
            onTap: canWrite
                ? () => _showEditProductSheet(context, product)
                : null,
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
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

    return RefreshIndicator(
      onRefresh: context.read<WarehouseBloc>().reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + kLiquidNavClearance,
        ),
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
                      formatLocalizedDateTime(
                        context,
                        m.occurredAt,
                        style: LocalizedDateTimeStyle.dateTime,
                      ),
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

  Widget _buildBatchesTab(
    BuildContext context,
    WarehouseLoaded state, {
    required bool canManage,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<WarehouseBloc>().add(
          LoadBatchesRequested(expiringOnly: state.batchesExpiringOnly),
        );
        await context.read<WarehouseBloc>().reload();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + kLiquidNavClearance,
        ),
        children: [
          const LedgerAdvicePanel(module: 'warehouse'),
          Row(
            children: [
              Expanded(
                child: Text(
                  localeCubit.translate('warehouse_batches_filter_expiring'),
                  style: textStyles.captionSans,
                ),
              ),
              Switch.adaptive(
                value: state.batchesExpiringOnly,
                activeThumbColor: colors.brand,
                onChanged: (v) {
                  context.read<WarehouseBloc>().add(
                    LoadBatchesRequested(expiringOnly: v),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.batches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  localeCubit.translate('warehouse_empty_batches'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            )
          else
            ...state.batches.map((batch) {
              final tone = batch.isExpired
                  ? colors.accentRed
                  : batch.isUrgent
                  ? colors.accentAmber
                  : colors.textSecondary;
              final riskLabel = batch.isExpired
                  ? localeCubit.translate('warehouse_batch_expired')
                  : batch.isUrgent
                  ? localeCubit.translate('warehouse_batch_urgent')
                  : (batch.daysLeft != null
                        ? localeCubit.translate(
                            'warehouse_batch_days_left',
                            params: {'days': '${batch.daysLeft}'},
                          )
                        : localeCubit.translate('warehouse_batch_no_expiry'));

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  onTap: canManage
                      ? () => _showEditBatchDialog(context, batch)
                      : null,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              batch.productName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          LedgerPill(
                            text: riskLabel,
                            backgroundColor: tone.withValues(alpha: 0.12),
                            textColor: tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localeCubit.translate(
                          'warehouse_batch_qty',
                          params: {
                            'qty': formatLocalizedNumber(context, batch.qty),
                            'unit': batch.unit ?? '',
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (batch.expiryDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          localeCubit.translate(
                            'warehouse_batch_expiry',
                            params: {
                              'date': formatLocalizedDateTime(
                                context,
                                batch.expiryDate!,
                                style: LocalizedDateTimeStyle.date,
                              ),
                            },
                          ),
                          style: textStyles.smallSans.copyWith(color: tone),
                        ),
                      ],
                      if (batch.code != null && batch.code!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          localeCubit.translate(
                            'warehouse_batch_code',
                            params: {'code': batch.code},
                          ),
                          style: textStyles.smallSans.copyWith(
                            color: colors.textTooltip,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Strip markdown markers from AI summary (web AnalysisTab parity).
  String _plainAiText(String md) {
    return md
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
        .trim();
  }

  Widget _buildAnalysisTab(BuildContext context, WarehouseLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final analysis = state.stockAnalysis;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(TablerIcons.chart_bar, size: 20, color: colors.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      language.translate('warehouse_analysis_title'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                language.translate('warehouse_analysis_subtitle'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: state.isAnalysisLoading
                    ? null
                    : () => context.read<WarehouseBloc>().add(
                        const RunStockAnalysisRequested(),
                      ),
                icon: state.isAnalysisLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.surface,
                        ),
                      )
                    : const Icon(TablerIcons.refresh, size: 18),
                label: Text(
                  language.translate(
                    analysis == null
                        ? 'warehouse_analysis_run'
                        : 'warehouse_analysis_rerun',
                  ),
                ),
              ),
              if (analysis == null && !state.isAnalysisLoading) ...[
                const SizedBox(height: 10),
                Text(
                  language.translate('warehouse_analysis_idle'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (state.isAnalysisLoading) ...[
          const SizedBox(height: 16),
          Text(
            language.translate('warehouse_analysis_waiting'),
            textAlign: TextAlign.center,
            style: textStyles.captionSans.copyWith(color: colors.textTooltip),
          ),
        ],
        if (state.analysisError != null) ...[
          const SizedBox(height: 12),
          Text(
            language.resolveMessage(state.analysisError!),
            style: textStyles.captionSans.copyWith(color: colors.accentRed),
          ),
        ],
        if (analysis != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('warehouse_analysis_stat_items'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analysis.totalItems}',
                        style: textStyles.h2Sans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('warehouse_analysis_stat_zero'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${analysis.zeroItems}',
                        style: textStyles.h2Sans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('warehouse_analysis_stat_value'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        oCcy.format(analysis.stockValue),
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: analysis.atRiskAmount > 0
                      ? colors.accentRed.withValues(alpha: 0.4)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.translate('warehouse_analysis_stat_risk'),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        oCcy.format(analysis.atRiskAmount),
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w500,
                          color: analysis.atRiskAmount > 0
                              ? colors.accentRed
                              : colors.textPrimary,
                        ),
                      ),
                      Text(
                        language.translate(
                          'warehouse_analysis_stat_risk_hint',
                          params: {
                            'count': '${analysis.expiringCount}',
                            'expired': '${analysis.expiredCount}',
                          },
                        ),
                        style: textStyles.smallSans.copyWith(
                          color: colors.textTooltip,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (analysis.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            LedgerCard(
              borderColor: colors.accentAmber.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.translate('warehouse_analysis_summary_title'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _plainAiText(analysis.summary),
                    style: textStyles.captionSans,
                  ),
                ],
              ),
            ),
          ],
          if (analysis.lowStock.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              language.translate('warehouse_analysis_low_stock'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...analysis.lowStock.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(row.name, style: textStyles.bodySans),
                      ),
                      Text(
                        '${formatLocalizedNumber(context, row.qty)} ${row.unit}',
                        style: textStyles.smallMono.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (analysis.expiring.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              language.translate('warehouse_analysis_risk_title'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              language.translate('warehouse_analysis_risk_subtitle'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...analysis.expiring.map((row) {
              final tone = row.expired ? colors.accentRed : colors.accentAmber;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: tone.withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              row.productName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          LedgerPill(
                            text: row.expired
                                ? language.translate('warehouse_batch_expired')
                                : language.translate(
                                    'warehouse_batch_days_left',
                                    params: {'days': '${row.daysLeft}'},
                                  ),
                            backgroundColor: tone.withValues(alpha: 0.12),
                            textColor: tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        language.translate(
                          'warehouse_batch_qty',
                          params: {
                            'qty': formatLocalizedNumber(context, row.qty),
                            'unit': row.unit,
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (row.expiryDate != null)
                        Text(
                          language.translate(
                            'warehouse_batch_expiry',
                            params: {
                              'date': formatLocalizedDateTime(
                                context,
                                row.expiryDate!,
                                style: LocalizedDateTimeStyle.date,
                              ),
                            },
                          ),
                          style: textStyles.smallSans.copyWith(color: tone),
                        ),
                      Text(
                        language.translate(
                          'warehouse_analysis_at_risk_amount',
                          params: {'amount': oCcy.format(row.atRiskAmount)},
                        ),
                        style: textStyles.smallMono.copyWith(
                          color: colors.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  Future<void> _showEditBatchDialog(
    BuildContext context,
    WarehouseBatch batch,
  ) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final bloc = context.read<WarehouseBloc>();
    final state = bloc.state;
    WarehouseProduct? product;
    if (state is WarehouseLoaded) {
      for (final p in state.products) {
        if (p.id == batch.productId) {
          product = p;
          break;
        }
      }
    }
    final oldPrice = product?.price ?? 0;
    final qtyController = TextEditingController(
      text: formatLocalizedNumber(context, batch.qty),
    );
    final codeController = TextEditingController(text: batch.code ?? '');
    final noteController = TextEditingController(text: batch.note ?? '');
    final percentCtrl = TextEditingController(
      text: (batch.suggestedDiscount != null && batch.suggestedDiscount! > 0)
          ? '${batch.suggestedDiscount}'
          : '',
    );
    DateTime? expiry = batch.expiryDate;
    String? discountError;

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('warehouse_edit_batch_title'),
        builder: (sheetContext, setSheetState) {
          final parsed = parseLocalizedNumber(sheetContext, percentCtrl.text);
          final valid = parsed != null && parsed >= 1 && parsed <= 90;
          final newPrice = valid ? (oldPrice * (100 - parsed) / 100) : oldPrice;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_batch_qty_label'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_batch_code_label'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: expiry ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 3650),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setSheetState(() => expiry = picked);
                  }
                },
                icon: const Icon(TablerIcons.calendar, size: 18),
                label: Text(
                  expiry == null
                      ? language.translate('warehouse_batch_pick_expiry')
                      : formatLocalizedDateTime(
                          sheetContext,
                          expiry!,
                          style: LocalizedDateTimeStyle.date,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_batch_note_label'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language.translate('warehouse_discount_hint'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: percentCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodyMono,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_discount_percent'),
                ),
                onChanged: (_) => setSheetState(() => discountError = null),
              ),
              const SizedBox(height: 8),
              Text(
                language.translate(
                  'warehouse_discount_preview',
                  params: {
                    'old': formatLocalizedNumber(sheetContext, oldPrice),
                    'new': formatLocalizedNumber(sheetContext, newPrice),
                  },
                ),
                style: textStyles.captionSans,
              ),
              if (discountError != null) ...[
                const SizedBox(height: 8),
                Text(
                  discountError!,
                  style: textStyles.captionSans.copyWith(
                    color: colors.accentRed,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final percent = parseLocalizedNumber(
                      sheetContext,
                      percentCtrl.text,
                    );
                    if (percent == null || percent < 1 || percent > 90) {
                      setSheetState(() {
                        discountError = language.translate(
                          'warehouse_discount_err_percent',
                        );
                      });
                      return;
                    }
                    bloc.add(
                      ApplyBatchDiscountRequested(
                        batchId: batch.id,
                        percent: percent.round(),
                      ),
                    );
                    Navigator.of(sheetContext).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accentAmber,
                    side: BorderSide(
                      color: colors.accentAmber.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(TablerIcons.tag, size: 18),
                  label: Text(
                    language.translate('warehouse_batch_discount_edit'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final didDelete = await _confirmDeleteBatch(
                      this.context,
                      batch,
                    );
                    if (didDelete == true && sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accentRed,
                    side: BorderSide(
                      color: colors.accentRed.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(TablerIcons.trash, size: 18),
                  label: Text(language.translate('common_delete')),
                ),
              ),
            ],
          );
        },
        footerBuilder: (sheetContext, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final qty = parseLocalizedNumber(
                  sheetContext,
                  qtyController.text,
                );
                if (qty == null || qty < 0) return;
                bloc.add(
                  UpdateBatchRequested(
                    id: batch.id,
                    qty: qty,
                    expiryDate: expiry,
                    code: codeController.text.trim(),
                    note: noteController.text.trim(),
                  ),
                );
                Navigator.of(sheetContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(language.translate('common_save')),
            ),
          );
        },
      );
    } finally {
      qtyController.dispose();
      codeController.dispose();
      noteController.dispose();
      percentCtrl.dispose();
    }
  }

  Future<void> _showAddBatchDialog(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final bloc = context.read<WarehouseBloc>();
    final state = bloc.state;
    if (state is! WarehouseLoaded || state.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.translate('warehouse_empty_products'))),
      );
      return;
    }

    String? productId = state.products.first.id;
    final qtyController = TextEditingController();
    final codeController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? expiry;

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('warehouse_add_batch_title'),
        builder: (sheetContext, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansibleWidget<String>.selection(
                title: Text(language.translate('warehouse_batch_product')),
                items: state.products.map((p) => p.id).toList(),
                selectedValue: productId,
                itemLabelBuilder: (id) {
                  final p = state.products.firstWhere((e) => e.id == id);
                  return p.name;
                },
                onSelected: (id) => setSheetState(() => productId = id),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_batch_qty_label'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_batch_code_label'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate:
                        expiry ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setSheetState(() => expiry = picked);
                  }
                },
                icon: const Icon(TablerIcons.calendar, size: 18),
                label: Text(
                  expiry == null
                      ? language.translate('warehouse_batch_pick_expiry')
                      : formatLocalizedDateTime(
                          sheetContext,
                          expiry!,
                          style: LocalizedDateTimeStyle.date,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_batch_note_label'),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final qty = parseLocalizedNumber(
                    sheetContext,
                    qtyController.text,
                  );
                  if (productId == null || qty == null || qty <= 0) return;
                  bloc.add(
                    CreateBatchRequested(
                      productId: productId!,
                      qty: qty,
                      expiryDate: expiry,
                      code: codeController.text.trim().isEmpty
                          ? null
                          : codeController.text.trim(),
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    ),
                  );
                  Navigator.of(sheetContext).pop();
                },
                child: Text(language.translate('common_save')),
              ),
            ],
          );
        },
      );
    } finally {
      qtyController.dispose();
      codeController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _showAddProductDialog(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final unitController = TextEditingController(
      text: language.translate('warehouse_unit_pieces_short'),
    );
    final priceController = TextEditingController();
    final costController = TextEditingController();
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
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_cost_price_label'),
                  hintText: language.translate('warehouse_cost_price_hint'),
                ),
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
              final cost = parseLocalizedNumber(context, costController.text);
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
                    costPrice: cost,
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
      costController.dispose();
      stockController.dispose();
    }
  }

  Future<void> _showEditProductSheet(
    BuildContext context,
    WarehouseProduct product,
  ) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final authState = context.read<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.warehouse);

    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku ?? '');
    final unitController = TextEditingController(text: product.unit);
    final priceController = TextEditingController(
      text: formatLocalizedNumber(context, product.price),
    );
    final costController = TextEditingController(
      text: product.costPrice == null
          ? ''
          : formatLocalizedNumber(context, product.costPrice!),
    );

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('warehouse_edit_product_title'),
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_product_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_sku'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_unit'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_price'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('warehouse_cost_price_label'),
                  hintText: language.translate('warehouse_cost_price_hint'),
                ),
              ),
              const SizedBox(height: 20),
              if (canManage) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final didZeroOut = await _confirmZeroOut(
                        this.context,
                        product,
                      );
                      if (didZeroOut == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accentAmber,
                      side: BorderSide(
                        color: colors.accentAmber.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(TablerIcons.circle_off, size: 18),
                    label: Text(language.translate('warehouse_zero_out')),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final didDelete = await _confirmDeleteProduct(
                        this.context,
                        product,
                      );
                      if (didDelete == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accentRed,
                      side: BorderSide(
                        color: colors.accentRed.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(TablerIcons.trash, size: 18),
                    label: Text(language.translate('common_delete')),
                  ),
                ),
              ],
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final price =
                    parseLocalizedNumber(
                      context,
                      priceController.text.trim(),
                    ) ??
                    product.price;
                this.context.read<WarehouseBloc>().add(
                  UpdateProductRequested(
                    product.copyWith(
                      name: name,
                      sku: skuController.text.trim().isEmpty
                          ? null
                          : skuController.text.trim(),
                      unit: unitController.text.trim().isEmpty
                          ? product.unit
                          : unitController.text.trim(),
                      price: price,
                      costPrice: parseLocalizedNumber(
                        context,
                        costController.text,
                      ),
                    ),
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(language.translate('common_save')),
            ),
          );
        },
      );
    } finally {
      nameController.dispose();
      skuController.dispose();
      unitController.dispose();
      priceController.dispose();
      costController.dispose();
    }
  }

  Future<bool?> _confirmDeleteProduct(
    BuildContext context,
    WarehouseProduct product,
  ) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final bloc = context.read<WarehouseBloc>();

    return LedgerBottomSheet.show<bool>(
      context: context,
      title: language.translate('warehouse_delete_title'),
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate(
                'warehouse_delete_msg',
                params: {'name': product.name},
              ),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  bloc.add(DeleteProductRequested(product.id));
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentRed,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('common_delete'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('common_cancel'),
                  style: textStyles.bodySans,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeleteBatch(
    BuildContext context,
    WarehouseBatch batch,
  ) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final bloc = context.read<WarehouseBloc>();

    return LedgerBottomSheet.show<bool>(
      context: context,
      title: language.translate('warehouse_delete_batch_title'),
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate(
                'warehouse_delete_batch_msg',
                params: {
                  'product': batch.productName,
                  'qty': formatLocalizedNumber(ctx, batch.qty),
                },
              ),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  bloc.add(DeleteBatchRequested(batch.id));
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentRed,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('common_delete'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('common_cancel'),
                  style: textStyles.bodySans,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmZeroOut(
    BuildContext context,
    WarehouseProduct product,
  ) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final bloc = context.read<WarehouseBloc>();

    return LedgerBottomSheet.show<bool>(
      context: context,
      title: language.translate('warehouse_zero_out_title'),
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate(
                'warehouse_zero_out_msg',
                params: {'name': product.name},
              ),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  bloc.add(ZeroOutProductRequested(product.id));
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentAmber,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('warehouse_zero_out'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  language.translate('common_cancel'),
                  style: textStyles.bodySans,
                ),
              ),
            ),
          ],
        );
      },
    );
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
                  fontWeight: FontWeight.w500,
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
