import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/network/api_client.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/models/ui_feedback.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/warehouse/bloc/warehouse_bloc.dart';
import '../../../features/warehouse/bloc/warehouse_event.dart';
import '../../../features/warehouse/bloc/warehouse_state.dart';
import '../../../features/warehouse/domain/warehouse_models.dart';
import '../../../features/warehouse/domain/warehouse_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_barcode_scanner.dart';
import '../../../presentation/widgets/ledger_scan_capture.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_fab.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../assistant/presentation/ledger_ai_assistant.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
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

enum WarehouseSection { products, movements, batches, analysis }

String _warehouseSectionTitle(
  LanguageCubit language,
  WarehouseSection section,
) {
  return language.translate(switch (section) {
    WarehouseSection.products => 'warehouse_tab_products',
    WarehouseSection.movements => 'warehouse_tab_movements',
    WarehouseSection.batches => 'warehouse_tab_batches',
    WarehouseSection.analysis => 'warehouse_tab_analysis',
  });
}

void _openWarehouseSection(BuildContext context, WarehouseSection section) {
  final bloc = context.read<WarehouseBloc>();
  if (section == WarehouseSection.analysis) {
    final state = bloc.state;
    if (state is WarehouseLoaded &&
        state.stockAnalysis == null &&
        !state.isAnalysisLoading) {
      bloc.add(const RunStockAnalysisRequested());
    }
  }
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: WarehouseSectionScreen(section: section),
      ),
    ),
  );
}

Future<void> _refreshWarehouse(BuildContext context) {
  final bloc = context.read<WarehouseBloc>();
  bloc.add(const LoadWarehouseData());
  return bloc.stream.firstWhere((state) => state is! WarehouseLoading);
}

class WarehouseView extends StatefulWidget {
  const WarehouseView({super.key});

  @override
  State<WarehouseView> createState() => _WarehouseViewState();
}

class _WarehouseViewState extends State<WarehouseView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<WarehouseBloc>();
      if (bloc.state is! WarehouseLoaded) {
        bloc.add(LoadWarehouseData());
      }
    });
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
      floatingActionButtonLocation: kLedgerShellFabLocation,
      floatingActionButton: const LedgerAiFloatingButton(),
      appBar: AppBar(
        title: Text(
          localeCubit.translate('warehouse_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    size: 20,
                  ),
                ),
              ]
            : null,
      ),
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
            } else if (state.feedback != null) {
              final fb = state.feedback!;
              final text = switch (fb) {
                WarehouseActionFeedback(:final translationKey, :final count) =>
                  localeCubit.translate(
                    translationKey,
                    params: {'count': '$count'},
                  ),
                LocalizedFeedback(:final translationKey, :final params) =>
                  localeCubit.translate(translationKey, params: params),
                ShiftClosedFeedback(
                  :final diffFormatted,
                  :final expectedFormatted,
                ) =>
                  localeCubit.translate(
                    'cash_shift_closed_diff',
                    params: {
                      'diff': diffFormatted,
                      'expected': expectedFormatted,
                    },
                  ),
              };
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(text),
                  backgroundColor: colors.accentGreen,
                ),
              );
            } else if (state.successMessage != null) {
              final raw = state.successMessage!;
              final parts = raw.split('|');
              final text = parts.length == 2
                  ? localeCubit.translate(parts[0], params: {'count': parts[1]})
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
                  previous.batchesExpiringOnly != current.batchesExpiringOnly ||
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
              return _buildOverviewHome(context, state, canManage: canManage);
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildOverviewHome(
    BuildContext context,
    WarehouseLoaded state, {
    required bool canManage,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final recentMovements = state.movements.take(5).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshWarehouse(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + kLiquidNavClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Total stock value
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localeCubit.translate('warehouse_stats_value'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localeCubit.translate(
                      'warehouse_amount_tjs',
                      params: {
                        'amount': oCcy.format(state.summary.totalStockValue),
                      },
                    ),
                    style: textStyles.h1Sans.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(TablerIcons.box_seam, size: 16, color: colors.brand),
                      const SizedBox(width: 6),
                      Text(
                        '${localeCubit.translate('warehouse_stats_count')}: ${state.summary.productsCount}',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Attention & Risk Alerts
            _buildWarehouseAttention(context, state),
            const SizedBox(height: 16),

            // 3. Quick Action Buttons (if canManage)
            if (canManage) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddProductDialog(context),
                      icon: const Icon(TablerIcons.plus),
                      label: Text(
                        localeCubit.translate('warehouse_add_product_btn'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddMovementDialog(context),
                      icon: const Icon(TablerIcons.arrow_left_right),
                      label: Text(
                        localeCubit.translate('warehouse_movement_btn'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // 4. Section Grid Hub (2x2)
            Row(
              children: [
                Expanded(
                  child: _buildHubTile(
                    context,
                    icon: TablerIcons.box,
                    title: localeCubit.translate('warehouse_tab_products'),
                    subtitle: '${state.products.length} поз.',
                    onTap: () => _openWarehouseSection(
                      context,
                      WarehouseSection.products,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHubTile(
                    context,
                    icon: TablerIcons.arrows_exchange,
                    title: localeCubit.translate('warehouse_tab_movements'),
                    subtitle: '${state.movements.length} операций',
                    onTap: () => _openWarehouseSection(
                      context,
                      WarehouseSection.movements,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildHubTile(
                    context,
                    icon: TablerIcons.layers_linked,
                    title: localeCubit.translate('warehouse_tab_batches'),
                    subtitle: '${state.batches.length} партий',
                    onTap: () => _openWarehouseSection(
                      context,
                      WarehouseSection.batches,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHubTile(
                    context,
                    icon: TablerIcons.chart_pie,
                    title: localeCubit.translate('warehouse_tab_analysis'),
                    subtitle: 'Ликвидность и остатки',
                    onTap: () => _openWarehouseSection(
                      context,
                      WarehouseSection.analysis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Recent Movements Feed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localeCubit.translate('warehouse_recent_movements'),
                  style: textStyles.h2Sans.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => _openWarehouseSection(
                    context,
                    WarehouseSection.movements,
                  ),
                  child: Text(
                    localeCubit.translate('warehouse_all_movements'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recentMovements.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  localeCubit.translate('warehouse_empty_movements'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...recentMovements.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildMovementItem(context, m, oCcy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildHubTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final colors = context.colors;
  final textStyles = context.textStyles;

  return Material(
    color: colors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 19, color: colors.brand),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 12.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildMovementItem(
  BuildContext context,
  WarehouseMovement m,
  dynamic oCcy,
) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final localeCubit = context.read<LanguageCubit>();
  final isIncome = m.direction == 'income';

  return Container(
    padding: const EdgeInsets.all(14),
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
            Expanded(
              child: Text(
                localeCubit.translateMessage(m.productName),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatLocalizedDateTime(
                context,
                m.occurredAt,
                style: LocalizedDateTimeStyle.dateTime,
              ),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
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
                  color: isIncome ? colors.accentGreen : colors.accentRed,
                ),
                const SizedBox(width: 4),
                Text(
                  isIncome
                      ? localeCubit.translate('warehouse_movement_income')
                      : localeCubit.translate('warehouse_movement_expense'),
                  style: textStyles.captionSans.copyWith(
                    color: isIncome ? colors.accentGreen : colors.accentRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: isIncome ? colors.accentGreen : colors.accentRed,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  localeCubit.translate(
                    'warehouse_amount_tjs',
                    params: {'amount': oCcy.format(m.amount)},
                  ),
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
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
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
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
  return Material(
    color: colors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: () => _openWarehouseSection(context, WarehouseSection.analysis),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasRisk ? colors.accentAmber : colors.border,
          ),
        ),
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
                      fontSize: 14.5,
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
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              TablerIcons.chevron_right,
              size: 18,
              color: colors.textTooltip,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Полноэкранный детальный просмотр раздела склада (Товары, Движения, Партии, Анализ).
class WarehouseSectionScreen extends StatelessWidget {
  final WarehouseSection section;

  const WarehouseSectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.warehouse);

    return BlocBuilder<WarehouseBloc, WarehouseState>(
      builder: (context, state) {
        final loadedState = state is WarehouseLoaded ? state : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _warehouseSectionTitle(language, section),
              style: textStyles.h2Sans.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            leading: const BackButton(),
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              if (section == WarehouseSection.products &&
                  loadedState != null) ...[
                IconButton(
                  tooltip: language.translate('warehouse_print_labels_btn'),
                  onPressed: () => _showPrintLabelsBottomSheet(
                    context,
                    loadedState.products,
                  ),
                  icon: const Icon(TablerIcons.printer, size: 20),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    icon: const Icon(TablerIcons.dots_vertical, size: 20),
                    onSelected: (val) {
                      if (val == 'generate_missing_barcodes') {
                        context.read<WarehouseBloc>().add(
                          const AssignMissingBarcodesRequested(),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'generate_missing_barcodes',
                        child: Row(
                          children: [
                            const Icon(TablerIcons.barcode, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              language.translate(
                                'warehouse_generate_missing_barcodes_btn',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
              if (section == WarehouseSection.analysis)
                IconButton(
                  tooltip: language.translate('warehouse_analysis_rerun'),
                  onPressed: () {
                    context.read<WarehouseBloc>().add(
                      const RunStockAnalysisRequested(),
                    );
                  },
                  icon: const Icon(TablerIcons.refresh, size: 20),
                ),
            ],
          ),
          floatingActionButton: canManage && loadedState != null
              ? switch (section) {
                  WarehouseSection.products => LedgerFab(
                    heroTag: null,
                    onPressed: () => _showAddProductDialog(context),
                    icon: TablerIcons.plus,
                    label: language.translate('warehouse_add_product_btn'),
                  ),
                  WarehouseSection.movements => LedgerFab(
                    heroTag: null,
                    onPressed: () => _showAddMovementDialog(context),
                    icon: TablerIcons.arrow_left_right,
                    label: language.translate('warehouse_movement_btn'),
                  ),
                  WarehouseSection.batches => LedgerFab(
                    heroTag: null,
                    onPressed: () => _showAddBatchDialog(context),
                    icon: TablerIcons.layers_linked,
                    label: language.translate('warehouse_add_batch_btn'),
                  ),
                  _ => null,
                }
              : null,
          body: BlocListener<WarehouseBloc, WarehouseState>(
            listener: (context, state) {
              if (state is WarehouseLoaded &&
                  state.pdfBytes != null &&
                  state.pdfBytes!.isNotEmpty) {
                final bytes = state.pdfBytes!;
                () async {
                  try {
                    final tempDir = await getTemporaryDirectory();
                    final file = File(
                      '${tempDir.path}/warehouse_labels_${DateTime.now().millisecondsSinceEpoch}.pdf',
                    );
                    await file.writeAsBytes(bytes);
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(file.path, mimeType: 'application/pdf')],
                      ),
                    );
                  } catch (_) {}
                }();
              }
            },
            child: loadedState != null
                ? switch (section) {
                    WarehouseSection.products => _buildProductsTab(
                      context,
                      loadedState,
                    ),
                    WarehouseSection.movements => _buildMovementsTab(
                      context,
                      loadedState,
                    ),
                    WarehouseSection.batches => _buildBatchesTab(
                      context,
                      loadedState,
                      canManage: canManage,
                    ),
                    WarehouseSection.analysis => _buildAnalysisTab(
                      context,
                      loadedState,
                    ),
                  }
                : switch (section) {
                    WarehouseSection.products =>
                      const WarehouseProductsShimmer(),
                    WarehouseSection.analysis =>
                      const WarehouseAnalysisShimmer(),
                    _ => const LedgerListShimmer(itemCount: 6),
                  },
          ),
        );
      },
    );
  }
}

Widget _buildProductsTab(BuildContext context, WarehouseLoaded state) {
  return _WarehouseProductsTab(state: state);
}

class _WarehouseProductsTab extends StatefulWidget {
  const _WarehouseProductsTab({required this.state});

  final WarehouseLoaded state;

  @override
  State<_WarehouseProductsTab> createState() => _WarehouseProductsTabState();
}

class _WarehouseProductsTabState extends State<_WarehouseProductsTab> {
  final _search = TextEditingController();
  var _categories = <ProductCategory>[];
  var _categoryFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCategories();
    });
  }

  @override
  void didUpdateWidget(covariant _WarehouseProductsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.products != widget.state.products) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    List<ProductCategory> list;
    try {
      list = await context.read<WarehouseRepository>().getCategories();
    } catch (_) {
      final seen = <String>{};
      list = [
        for (final product in widget.state.products)
          if (product.categoryId != null &&
              product.categoryId!.isNotEmpty &&
              product.categoryName != null &&
              product.categoryName!.isNotEmpty &&
              seen.add(product.categoryId!))
            ProductCategory(
              id: product.categoryId!,
              name: product.categoryName!,
            ),
      ];
    }
    if (!mounted) return;
    setState(() => _categories = list);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesCategory(WarehouseProduct product) {
    return switch (_categoryFilter) {
      '' => true,
      'none' => product.categoryId == null || product.categoryId!.isEmpty,
      _ => product.categoryId == _categoryFilter,
    };
  }

  List<WarehouseProduct> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return widget.state.products.where((p) {
      final matchesQuery =
          q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false) ||
          (p.barcode?.toLowerCase().contains(q) ?? false);
      return matchesQuery && _matchesCategory(p);
    }).toList();
  }

  String _categoryFilterLabel(LanguageCubit language) {
    return switch (_categoryFilter) {
      '' => language.translate('warehouse_filter_all_categories'),
      'none' => language.translate('warehouse_filter_no_category'),
      _ =>
        _categories
                .where((c) => c.id == _categoryFilter)
                .map((c) => c.name)
                .firstOrNull ??
            widget.state.products
                .where((p) => p.categoryId == _categoryFilter)
                .map((p) => p.categoryName)
                .whereType<String>()
                .firstOrNull ??
            language.translate('warehouse_filter_all_categories'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: () async {
        await _refreshWarehouse(context);
        await _loadCategories();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + kLiquidNavClearance,
        ),
        itemCount: filtered.isEmpty ? 3 : filtered.length + 2,
        separatorBuilder: (context, index) =>
            SizedBox(height: index == 0 ? 16 : 12),
        itemBuilder: (context, index) {
          if (index == 1) {
            final showCategoryFilter =
                _categories.isNotEmpty ||
                state.products.any(
                  (p) => p.categoryId != null && p.categoryId!.isNotEmpty,
                );
            final categoryItems = <String>[
              '',
              if (state.products.any(
                (p) => p.categoryId == null || p.categoryId!.isEmpty,
              ))
                'none',
              ..._categories.map((c) => c.id),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: localeCubit.translate('warehouse_search_hint'),
                    prefixIcon: Icon(
                      TablerIcons.search,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    suffixIcon: IconButton(
                      tooltip: localeCubit.translate('scan_barcode_title'),
                      onPressed: () async {
                        final code = await LedgerBarcodeScanner.open(context);
                        if (code == null || !mounted) return;
                        setState(() => _search.text = code);
                      },
                      icon: Icon(TablerIcons.camera, color: colors.brand),
                    ),
                  ),
                ),
                if (showCategoryFilter) ...[
                  const SizedBox(height: 8),
                  ExpansibleWidget<String>.selection(
                    cardPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    title: Text(
                      _categoryFilterLabel(localeCubit),
                      style: textStyles.bodySans,
                    ),
                    items: categoryItems,
                    selectedValue: _categoryFilter,
                    itemLabelBuilder: (id) => switch (id) {
                      '' => localeCubit.translate(
                        'warehouse_filter_all_categories',
                      ),
                      'none' => localeCubit.translate(
                        'warehouse_filter_no_category',
                      ),
                      _ =>
                        _categories
                                .where((c) => c.id == id)
                                .map((c) => c.name)
                                .firstOrNull ??
                            id,
                    },
                    onSelected: (id) => setState(() => _categoryFilter = id),
                  ),
                ],
              ],
            );
          }
          if (index == 0) {
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localeCubit.translate('warehouse_stats_count'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${state.summary.productsCount}',
                            style: textStyles.h1Sans.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localeCubit.translate('warehouse_stats_value'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
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
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
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

          if (filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64.0),
                child: Text(
                  localeCubit.translate('warehouse_empty_products'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }

          final product = filtered[index - 2];
          final auth = context.watch<AuthBloc>().state;
          final canWrite =
              auth is AuthAuthenticated &&
              auth.role.canWrite(AppCapability.warehouse);

          final isOutOfStock = product.stockQty <= 0;
          final isLowStock = product.minStock != null
              ? product.stockQty <= product.minStock!
              : !isOutOfStock && product.stockQty <= 5;

          final stockStatusColor = isOutOfStock
              ? colors.accentRed
              : (isLowStock ? colors.accentAmber : colors.accentGreen);

          return Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: canWrite
                  ? () => _showEditProductSheet(context, product)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    _ProductThumb(product: product),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localeCubit.translateMessage(product.name),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product.categoryName != null &&
                              product.categoryName!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              product.categoryName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (product.sku != null &&
                                  product.sku!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceNested,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    product.sku!,
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                localeCubit.translate(
                                  'warehouse_product_price',
                                  params: {'price': oCcy.format(product.price)},
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (product.barcode != null &&
                              product.barcode!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  TablerIcons.barcode,
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  product.barcode!,
                                  style: textStyles.captionSans.copyWith(
                                    fontFamily: 'monospace',
                                    color: colors.textSecondary,
                                    fontSize: 11.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: stockStatusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            localeCubit.translate(
                              'warehouse_quantity_with_unit',
                              params: {
                                'quantity': formatLocalizedNumber(
                                  context,
                                  product.stockQty,
                                ),
                                'unit': localeCubit.translateMessage(
                                  product.unit,
                                ),
                              },
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: stockStatusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (isLowStock) ...[
                          const SizedBox(height: 4),
                          Text(
                            localeCubit.translate('warehouse_low_stock'),
                            style: textStyles.captionSans.copyWith(
                              color: isOutOfStock
                                  ? colors.accentRed
                                  : colors.accentAmber,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
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
                          style: textStyles.captionSans.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildMovementsTab(BuildContext context, WarehouseLoaded state) {
  final colors = context.colors;
  final textStyles = context.textStyles;
  final localeCubit = context.read<LanguageCubit>();
  final oCcy = localizedDecimalFormat(context);

  return RefreshIndicator(
    onRefresh: () => _refreshWarehouse(context),
    child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + kLiquidNavClearance),
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
                  fontSize: 14,
                ),
              ),
            ),
          );
        }
        final m = state.movements[index];
        return _buildMovementItem(context, m, oCcy);
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
      final bloc = context.read<WarehouseBloc>();
      bloc.add(LoadBatchesRequested(expiringOnly: state.batchesExpiringOnly));
      await bloc.stream.firstWhere((s) => s is! WarehouseLoading);
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + kLiquidNavClearance),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  localeCubit.translate('warehouse_batches_filter_expiring'),
                  style: textStyles.captionSans.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
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
        ),
        const SizedBox(height: 12),
        if (state.batches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                localeCubit.translate('warehouse_empty_batches'),
                style: textStyles.bodySans.copyWith(
                  color: colors.textTooltip,
                  fontSize: 14,
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
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: canManage
                      ? () => _showEditBatchDialog(context, batch)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: batch.isExpired || batch.isUrgent
                            ? tone.withValues(alpha: 0.5)
                            : colors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                batch.productName,
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tone.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                riskLabel,
                                style: textStyles.captionSans.copyWith(
                                  color: tone,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
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
                            fontSize: 13,
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
                            style: textStyles.captionSans.copyWith(
                              color: tone,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        if (batch.code != null && batch.code!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            localeCubit.translate(
                              'warehouse_batch_code',
                              params: {'code': batch.code},
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textTooltip,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + kLiquidNavClearance),
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
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
                fontSize: 13,
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
                  : const Icon(TablerIcons.refresh),
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
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
      if (state.isAnalysisLoading) ...[
        const SizedBox(height: 16),
        const LedgerShimmer(child: LedgerTextBlockShimmer()),
      ],
      if (state.analysisError != null) ...[
        const SizedBox(height: 12),
        Text(
          language.resolveMessage(state.analysisError!),
          style: textStyles.captionSans.copyWith(
            color: colors.accentRed,
            fontSize: 13,
          ),
        ),
      ],
      if (analysis != null) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('warehouse_analysis_stat_items'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${analysis.totalItems}',
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('warehouse_analysis_stat_zero'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${analysis.zeroItems}',
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
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
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('warehouse_analysis_stat_value'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oCcy.format(analysis.stockValue),
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: analysis.atRiskAmount > 0
                        ? colors.accentRed.withValues(alpha: 0.4)
                        : colors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('warehouse_analysis_stat_risk'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      oCcy.format(analysis.atRiskAmount),
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: analysis.atRiskAmount > 0
                            ? colors.accentRed
                            : colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.translate(
                        'warehouse_analysis_stat_risk_hint',
                        params: {
                          'count': '${analysis.expiringCount}',
                          'expired': '${analysis.expiredCount}',
                        },
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textTooltip,
                        fontSize: 12,
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.accentAmber.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.translate('warehouse_analysis_summary_title'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _plainAiText(analysis.summary),
                  style: textStyles.captionSans.copyWith(
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (analysis.lowStock.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            language.translate('warehouse_analysis_low_stock'),
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.lowStock.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.name,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Text(
                      '${formatLocalizedNumber(context, row.qty)} ${row.unit}',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            language.translate('warehouse_analysis_risk_subtitle'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.expiring.map((row) {
            final tone = row.expired ? colors.accentRed : colors.accentAmber;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tone.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.productName,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tone.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            row.expired
                                ? language.translate('warehouse_batch_expired')
                                : language.translate(
                                    'warehouse_batch_days_left',
                                    params: {'days': '${row.daysLeft}'},
                                  ),
                            style: textStyles.captionSans.copyWith(
                              color: tone,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
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
                        fontSize: 13,
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
                        style: textStyles.captionSans.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      language.translate(
                        'warehouse_analysis_at_risk_amount',
                        params: {'amount': oCcy.format(row.atRiskAmount)},
                      ),
                      style: textStyles.bodyMono.copyWith(
                        color: colors.accentRed,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: kLedgerModalButtonHeight,
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
              height: kLedgerModalButtonHeight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final didDelete = await _confirmDeleteBatch(context, batch);
                  if (didDelete == true && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accentRed,
                  side: BorderSide(
                    color: colors.accentRed.withValues(alpha: 0.5),
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
        return ElevatedButton(
          onPressed: () {
            final qty = parseLocalizedNumber(sheetContext, qtyController.text);
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
          child: Text(language.translate('common_save')),
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
  final barcodeController = TextEditingController();
  final skuController = TextEditingController();
  final nameFocus = FocusNode();
  final barcodeFocus = FocusNode();
  final skuFocus = FocusNode();
  final unitFocus = FocusNode();
  final priceFocus = FocusNode();
  final costFocus = FocusNode();
  final stockFocus = FocusNode();
  final minStockFocus = FocusNode();
  final categoryNameFocus = FocusNode();
  final unitController = TextEditingController(
    text: language.translate('warehouse_unit_pieces_short'),
  );
  final priceController = TextEditingController();
  final costController = TextEditingController();
  final stockController = TextEditingController(text: '0');
  final minStockController = TextEditingController();
  final categoryNameController = TextEditingController();
  var categories = <ProductCategory>[];
  String? categoryId;
  String? imageUrl;

  try {
    try {
      categories = await context.read<WarehouseRepository>().getCategories();
    } catch (_) {}
    if (!context.mounted) return;
    await LedgerBottomSheet.show(
      context: context,
      title: language.translate('warehouse_add_product_title'),
      builder: (context, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LedgerScanCapture(
              barcode: barcodeController,
              barcodeFocus: barcodeFocus,
              name: nameController,
              nameFocus: nameFocus,
              anywhere: true,
              focusBarcodeOnStart: true,
              fields: [
                ScanField(barcodeFocus, barcodeController),
                ScanField(nameFocus, nameController),
                ScanField(skuFocus, skuController),
                ScanField(unitFocus, unitController),
                ScanField(priceFocus, priceController),
                ScanField(costFocus, costController),
                ScanField(stockFocus, stockController),
                ScanField(minStockFocus, minStockController),
                ScanField(categoryNameFocus, categoryNameController),
              ],
            ),
            TextField(
              controller: barcodeController,
              focusNode: barcodeFocus,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: language.translate('warehouse_barcode_label'),
                suffixIcon: IconButton(
                  tooltip: language.translate('scan_barcode_title'),
                  onPressed: () async {
                    final code = await LedgerBarcodeScanner.open(context);
                    if (code == null || code.isEmpty) return;
                    barcodeController.text = code;
                    nameFocus.requestFocus();
                  },
                  icon: Icon(TablerIcons.barcode, color: context.colors.brand),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              focusNode: nameFocus,
              decoration: InputDecoration(
                labelText: language.translate('warehouse_product_name'),
              ),
            ),
            const SizedBox(height: 12),
            _CategoryEditor(
              categories: categories,
              categoryId: categoryId,
              nameController: categoryNameController,
              nameFocus: categoryNameFocus,
              onChanged: (next, id) => setSheetState(() {
                categories = next;
                categoryId = id;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: skuController,
              focusNode: skuFocus,
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
                    focusNode: unitFocus,
                    decoration: InputDecoration(
                      labelText: language.translate('warehouse_unit_label'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    focusNode: priceFocus,
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
              focusNode: costFocus,
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
              focusNode: stockFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: language.translate('warehouse_initial_stock'),
              ),
            ),
            const SizedBox(height: 12),
            _MinStockPhoto(
              minStock: minStockController,
              minStockFocus: minStockFocus,
              imageUrl: imageUrl,
              onImage: (url) => setSheetState(() => imageUrl = url),
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
            final minStock = _readOptionalMinStock(context, minStockController);
            if (minStock == null && minStockController.text.trim().isNotEmpty) {
              return;
            }

            context.read<WarehouseBloc>().add(
              CreateProductRequested(
                WarehouseProduct(
                  id: '',
                  name: name,
                  sku: skuController.text.trim(),
                  barcode: barcodeController.text.trim().isEmpty
                      ? null
                      : barcodeController.text.trim(),
                  categoryId: categoryId,
                  categoryName: categories
                      .where((c) => c.id == categoryId)
                      .map((c) => c.name)
                      .firstOrNull,
                  minStock: minStock,
                  imageUrl: imageUrl,
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
    barcodeController.dispose();
    skuController.dispose();
    unitController.dispose();
    priceController.dispose();
    costController.dispose();
    stockController.dispose();
    minStockController.dispose();
    categoryNameController.dispose();
    nameFocus.dispose();
    barcodeFocus.dispose();
    skuFocus.dispose();
    unitFocus.dispose();
    priceFocus.dispose();
    costFocus.dispose();
    stockFocus.dispose();
    minStockFocus.dispose();
    categoryNameFocus.dispose();
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
  final barcodeController = TextEditingController(text: product.barcode ?? '');
  final skuController = TextEditingController(text: product.sku ?? '');
  final nameFocus = FocusNode();
  final barcodeFocus = FocusNode();
  final unitController = TextEditingController(text: product.unit);
  final priceController = TextEditingController(
    text: formatLocalizedNumber(context, product.price),
  );
  final costController = TextEditingController(
    text: product.costPrice == null
        ? ''
        : formatLocalizedNumber(context, product.costPrice!),
  );
  final minStockController = TextEditingController(
    text: product.minStock == null
        ? ''
        : formatLocalizedNumber(context, product.minStock!),
  );
  final categoryNameController = TextEditingController();
  final minStockFocus = FocusNode();
  final categoryNameFocus = FocusNode();
  var categories = <ProductCategory>[];
  var categoryId = product.categoryId;
  var imageUrl = product.imageUrl;

  try {
    try {
      categories = await context.read<WarehouseRepository>().getCategories();
    } catch (_) {}
    if (!context.mounted) return;
    await LedgerBottomSheet.show(
      context: context,
      title: language.translate('warehouse_edit_product_title'),
      builder: (context, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LedgerScanCapture(
              barcode: barcodeController,
              barcodeFocus: barcodeFocus,
              name: nameController,
              nameFocus: nameFocus,
              anywhere: false,
              fields: [
                ScanField(barcodeFocus, barcodeController),
                ScanField(nameFocus, nameController),
                ScanField(minStockFocus, minStockController),
                ScanField(categoryNameFocus, categoryNameController),
              ],
            ),
            TextField(
              controller: barcodeController,
              focusNode: barcodeFocus,
              textInputAction: TextInputAction.next,
              style: textStyles.bodySans,
              decoration: InputDecoration(
                labelText: language.translate('warehouse_barcode_label'),
                suffixIcon: IconButton(
                  tooltip: language.translate('scan_barcode_title'),
                  onPressed: () async {
                    final code = await LedgerBarcodeScanner.open(context);
                    if (code == null || code.isEmpty) return;
                    barcodeController.text = code;
                    nameFocus.requestFocus();
                  },
                  icon: Icon(TablerIcons.barcode, color: context.colors.brand),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              focusNode: nameFocus,
              style: textStyles.bodySans,
              decoration: InputDecoration(
                labelText: language.translate('warehouse_product_name'),
              ),
            ),
            const SizedBox(height: 12),
            _CategoryEditor(
              categories: categories,
              categoryId: categoryId,
              selectedName: product.categoryName,
              nameController: categoryNameController,
              nameFocus: categoryNameFocus,
              onChanged: (next, id) => setSheetState(() {
                categories = next;
                categoryId = id;
              }),
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
            const SizedBox(height: 12),
            _MinStockPhoto(
              minStock: minStockController,
              minStockFocus: minStockFocus,
              imageUrl: imageUrl,
              onImage: (url) => setSheetState(() => imageUrl = url),
            ),
            const SizedBox(height: 20),
            if (canManage &&
                (product.barcode == null || product.barcode!.isEmpty)) ...[
              SizedBox(
                width: double.infinity,
                height: kLedgerModalButtonHeight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<WarehouseBloc>().add(
                      AssignProductBarcodeRequested(productId: product.id),
                    );
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.brand,
                    side: BorderSide(color: colors.border),
                  ),
                  icon: const Icon(TablerIcons.barcode, size: 18),
                  label: Text(language.translate('warehouse_assign_barcode')),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (canManage) ...[
              SizedBox(
                width: double.infinity,
                height: kLedgerModalButtonHeight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final didZeroOut = await _confirmZeroOut(context, product);
                    if (didZeroOut == true && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accentAmber,
                    side: BorderSide(
                      color: colors.accentAmber.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(TablerIcons.circle_off, size: 18),
                  label: Text(language.translate('warehouse_zero_out')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: kLedgerModalButtonHeight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final didDelete = await _confirmDeleteProduct(
                      context,
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
                  ),
                  icon: const Icon(TablerIcons.trash, size: 18),
                  label: Text(language.translate('common_delete')),
                ),
              ),
            ],
          ],
        );
      },
      footerBuilder: (sheetContext, setSheetState) {
        return ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            final price =
                parseLocalizedNumber(
                  sheetContext,
                  priceController.text.trim(),
                ) ??
                product.price;
            final minStock = _readOptionalMinStock(
              sheetContext,
              minStockController,
            );
            if (minStock == null && minStockController.text.trim().isNotEmpty) {
              return;
            }
            final categoryName = categories
                .where((c) => c.id == categoryId)
                .map((c) => c.name)
                .firstOrNull;
            context.read<WarehouseBloc>().add(
              UpdateProductRequested(
                product.copyWith(
                  name: name,
                  sku: skuController.text.trim().isEmpty
                      ? null
                      : skuController.text.trim(),
                  barcode: barcodeController.text.trim().isEmpty
                      ? null
                      : barcodeController.text.trim(),
                  clearBarcode: barcodeController.text.trim().isEmpty,
                  categoryId: categoryId,
                  categoryName: categoryName ?? product.categoryName,
                  clearCategory: categoryId == null,
                  minStock: minStock,
                  clearMinStock: minStock == null,
                  imageUrl: imageUrl,
                  clearImage: imageUrl == null || imageUrl!.isEmpty,
                  unit: unitController.text.trim().isEmpty
                      ? product.unit
                      : unitController.text.trim(),
                  price: price,
                  costPrice: parseLocalizedNumber(
                    sheetContext,
                    costController.text,
                  ),
                ),
              ),
            );
            Navigator.pop(sheetContext);
          },
          child: Text(language.translate('common_save')),
        );
      },
    );
  } finally {
    nameController.dispose();
    barcodeController.dispose();
    skuController.dispose();
    unitController.dispose();
    priceController.dispose();
    costController.dispose();
    nameFocus.dispose();
    barcodeFocus.dispose();
    minStockController.dispose();
    categoryNameController.dispose();
    minStockFocus.dispose();
    categoryNameFocus.dispose();
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
            height: kLedgerModalButtonHeight,
            child: ElevatedButton(
              onPressed: () {
                bloc.add(DeleteProductRequested(product.id));
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentRed,
                foregroundColor: colors.surface,
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
            height: kLedgerModalButtonHeight,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
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
            height: kLedgerModalButtonHeight,
            child: ElevatedButton(
              onPressed: () {
                bloc.add(DeleteBatchRequested(batch.id));
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentRed,
                foregroundColor: colors.surface,
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
            height: kLedgerModalButtonHeight,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
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
            height: kLedgerModalButtonHeight,
            child: ElevatedButton(
              onPressed: () {
                bloc.add(ZeroOutProductRequested(product.id));
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentAmber,
                foregroundColor: colors.surface,
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
            height: kLedgerModalButtonHeight,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
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
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
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
                      labelText: language.translate('warehouse_quantity_label'),
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

void _showPrintLabelsBottomSheet(
  BuildContext context,
  List<WarehouseProduct> products,
) {
  final language = context.read<LanguageCubit>();
  final warehouseBloc = context.read<WarehouseBloc>();
  final colors = context.colors;
  final textStyles = context.textStyles;

  String sheetFormat = 'a4'; // 'a4' or 'label'
  int copies = 1;
  WarehouseProduct? selectedProduct; // null = all products

  LedgerBottomSheet.show(
    context: context,
    title: language.translate('warehouse_print_labels_title'),
    builder: (context, setSheetState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            language.translate('warehouse_print_format_label'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'Сетка А4 (3×8, 24 шт)',
                    style: textStyles.captionSans.copyWith(
                      fontWeight: sheetFormat == 'a4'
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  selected: sheetFormat == 'a4',
                  onSelected: (sel) {
                    if (sel) {
                      setSheetState(() => sheetFormat = 'a4');
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(
                    'Термолента 58 мм',
                    style: textStyles.captionSans.copyWith(
                      fontWeight: sheetFormat == 'label'
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  selected: sheetFormat == 'label',
                  onSelected: (sel) {
                    if (sel) {
                      setSheetState(() => sheetFormat = 'label');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            language.translate('warehouse_print_product_scope'),
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
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
                  ? 'Все товары (${products.length} шт)'
                  : '${selectedProduct!.name} (${selectedProduct!.barcode ?? 'без кода'})',
              style: textStyles.bodySans,
            ),
            items: [null, ...products],
            selectedValue: selectedProduct,
            itemLabelBuilder: (p) => p == null
                ? 'Все товары (${products.length} шт)'
                : '${p.name} (${p.barcode ?? 'без кода'})',
            onSelected: (p) {
              setSheetState(() {
                selectedProduct = p;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Копий на каждый товар: $copies',
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 5, 10].map((c) {
              final isSel = copies == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$c шт'),
                  selected: isSel,
                  onSelected: (sel) {
                    if (sel) setSheetState(() => copies = c);
                  },
                ),
              );
            }).toList(),
          ),
        ],
      );
    },
    footerBuilder: (context, setSheetState) {
      return ElevatedButton.icon(
        onPressed: () {
          final ids = selectedProduct != null
              ? [selectedProduct!.id]
              : products.map((p) => p.id).toList();
          if (ids.isEmpty) return;

          warehouseBloc.add(
            DownloadBarcodeLabelsPdfRequested(
              productIds: ids,
              sheet: sheetFormat,
              copies: copies,
            ),
          );
          Navigator.pop(context);
        },
        icon: const Icon(TablerIcons.printer, size: 18),
        label: Text(
          language.translate('warehouse_download_labels_pdf_btn'),
          style: textStyles.bodySans.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    },
  );
}

double? _readOptionalMinStock(
  BuildContext context,
  TextEditingController controller,
) {
  final raw = controller.text.trim();
  if (raw.isEmpty) return null;
  final value = parseLocalizedNumber(context, raw);
  if (value == null || value < 0) return null;
  return value;
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.product});

  final WarehouseProduct product;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(TablerIcons.box, size: 22, color: colors.brand),
    );
    final url = product.imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        ApiClient().mediaUrl(url),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.categories,
    required this.categoryId,
    required this.nameController,
    required this.nameFocus,
    required this.onChanged,
    this.selectedName,
  });

  final List<ProductCategory> categories;
  final String? categoryId;
  final String? selectedName;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final void Function(List<ProductCategory> categories, String? categoryId)
  onChanged;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  var _busy = false;

  Future<void> _add() async {
    final raw = widget.nameController.text.trim();
    if (raw.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final created = await context.read<WarehouseRepository>().createCategory(
        raw,
      );
      if (!mounted) return;
      widget.nameController.clear();
      widget.onChanged([...widget.categories, created], created.id);
    } catch (_) {
      if (!mounted) return;
      final language = context.read<LanguageCubit>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.translate('warehouse_category_error'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final textStyles = context.textStyles;
    final selected = widget.categoryId == null
        ? language.translate('warehouse_category_none')
        : widget.categories
                  .where((c) => c.id == widget.categoryId)
                  .map((c) => c.name)
                  .firstOrNull ??
              widget.selectedName ??
              language.translate('warehouse_category_none');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language.translate('warehouse_category'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        ExpansibleWidget<String>.selection(
          cardPadding: EdgeInsets.zero,
          title: Text(selected, style: textStyles.bodySans),
          items: ['', ...widget.categories.map((c) => c.id)],
          selectedValue: widget.categoryId ?? '',
          itemLabelBuilder: (id) => id.isEmpty
              ? language.translate('warehouse_category_none')
              : widget.categories
                        .where((c) => c.id == id)
                        .map((c) => c.name)
                        .firstOrNull ??
                    id,
          onSelected: (id) =>
              widget.onChanged(widget.categories, id.isEmpty ? null : id),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.nameController,
                focusNode: widget.nameFocus,
                decoration: InputDecoration(
                  labelText: widget.categories.isEmpty
                      ? language.translate('warehouse_category_empty')
                      : language.translate('warehouse_category_add'),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              onPressed: _busy ? null : _add,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(TablerIcons.plus, color: context.colors.brand),
            ),
          ],
        ),
      ],
    );
  }
}

class _MinStockPhoto extends StatefulWidget {
  const _MinStockPhoto({
    required this.minStock,
    required this.minStockFocus,
    required this.imageUrl,
    required this.onImage,
  });

  final TextEditingController minStock;
  final FocusNode minStockFocus;
  final String? imageUrl;
  final ValueChanged<String?> onImage;

  @override
  State<_MinStockPhoto> createState() => _MinStockPhotoState();
}

class _MinStockPhotoState extends State<_MinStockPhoto> {
  var _uploading = false;

  Future<void> _pick() async {
    if (_uploading) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await context.read<WarehouseRepository>().uploadImage(
        path,
        picked!.files.single.name,
      );
      if (!mounted) return;
      if (url.isNotEmpty) widget.onImage(url);
    } catch (_) {
      if (!mounted) return;
      final language = context.read<LanguageCubit>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(language.translate('warehouse_photo_error'))),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final textStyles = context.textStyles;
    final colors = context.colors;
    final imageUrl = widget.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.minStock,
          focusNode: widget.minStockFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: language.translate('warehouse_min_stock'),
            hintText: language.translate('warehouse_min_stock_hint'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          language.translate('warehouse_photo'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? Image.network(
                      ApiClient().mediaUrl(imageUrl),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _photoPlaceholder(context),
                    )
                  : _photoPlaceholder(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pick,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(TablerIcons.upload, size: 18),
                    label: Text(
                      hasImage
                          ? language.translate('warehouse_photo_replace')
                          : language.translate('warehouse_photo_upload'),
                    ),
                  ),
                  if (hasImage)
                    TextButton(
                      onPressed: () => widget.onImage(null),
                      child: Text(language.translate('common_delete')),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          language.translate('warehouse_photo_hint'),
          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _photoPlaceholder(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      child: Icon(TablerIcons.photo, color: colors.textSecondary),
    );
  }
}
