import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_fab.dart';
import '../../../presentation/widgets/ledger_segmented_control.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../bloc/network_bloc.dart';
import '../bloc/network_event.dart';
import '../bloc/network_state.dart';
import '../data/api_network_repository.dart';
import '../domain/network_models.dart';
import '../domain/network_repository.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    NetworkRepository repo;
    try {
      repo = context.read<NetworkRepository>();
    } catch (_) {
      repo = ApiNetworkRepository();
    }

    return BlocProvider<NetworkBloc>(
      create: (context) => NetworkBloc(repo)..add(const LoadNetworkData()),
      child: const _NetworkView(),
    );
  }
}

class _NetworkView extends StatefulWidget {
  const _NetworkView();

  @override
  State<_NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<_NetworkView> {
  int? _enteringStoreId;

  String _formatMoney(BuildContext context, double amount) {
    return '${formatLocalizedNumber(context, amount)} TJS';
  }

  Widget _networkAmount({required bool loading, required Widget child}) {
    if (!loading) return child;
    return LedgerShimmer(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isOwner =
        authState is AuthAuthenticated && authState.role == UserRole.owner;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          language.translate('network_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      floatingActionButton: isOwner
          ? LedgerFab(
              heroTag: null,
              onPressed: () => _showCreateStoreDialog(context),
              icon: TablerIcons.plus,
              label: language.translate('network_new_store'),
            )
          : null,
      body: BlocConsumer<NetworkBloc, NetworkState>(
        listener: (context, state) {
          if (state is NetworkLoaded && state.actionMessage != null) {
            final msg = state.actionMessage!;
            final text = msg.startsWith('network_') || msg.startsWith('error_')
                ? language.translate(msg)
                : language.translateMessage(msg);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(text),
                backgroundColor: _isNetworkSuccess(msg)
                    ? colors.accentGreen
                    : colors.accentRed,
              ),
            );
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  final bloc = context.read<NetworkBloc>();
                  bloc.add(
                    LoadNetworkData(
                      period: state is NetworkLoaded
                          ? state.period
                          : NetworkPeriod.month,
                      forceRefresh: true,
                    ),
                  );
                  await bloc.stream.firstWhere(
                    (s) =>
                        s is NetworkError ||
                        (s is NetworkLoaded && !s.isSummaryLoading),
                  );
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (state is NetworkLoading) ...[
                      const NetworkOverviewShimmer(),
                    ] else if (state is NetworkError) ...[
                      _buildErrorState(context, state.message),
                    ] else if (state is NetworkLoaded) ...[
                      if (state.actingStore != null) ...[
                        _buildActingStoreBanner(context, state.actingStore!),
                        const SizedBox(height: 12),
                      ],
                      _buildSummaryCard(context, state),
                      const SizedBox(height: 20),
                      Text(
                        language.translate('network_stores_list'),
                        style: textStyles.h2Sans.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (state.stores.isEmpty)
                        _buildEmptyStores(context, isOwner: isOwner)
                      else
                        for (final store in state.stores) ...[
                          _buildStoreCard(
                            context,
                            store,
                            state.summary.firstWhere(
                              (s) => s.storeId == store.id,
                              orElse: () => StoreSummaryRow(
                                storeId: store.id,
                                storeName: store.name,
                                isActive: store.isActive,
                              ),
                            ),
                            isCurrent: store.id == state.actingStore?.id,
                            summaryLoading: state.isSummaryLoading,
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActingStoreBanner(BuildContext context, ActingStore acting) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              TablerIcons.building_store,
              size: 20,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.translate('network_acting_store_label'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  acting.name,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.brand,
                    fontSize: 14.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              final bloc = context.read<NetworkBloc>();
              bloc.add(const LeaveStoreRequested());
              await bloc.stream.firstWhere(
                (s) => s is NetworkLoaded && !s.isSubmitting,
              );
              if (!context.mounted) return;
              ExpiringRequestCache.invalidateAll();
              context.read<AuthBloc>().add(const ActingStoreUpdated());
              context.go('/dashboard');
            },
            child: Text(language.translate('network_leave_store')),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, NetworkLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

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
          _buildPeriodSwitcher(context, state.period),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.translate('network_total_profit'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _networkAmount(
                      loading: state.isSummaryLoading,
                      child: Text(
                        _formatMoney(context, state.totalProfit),
                        style: textStyles.displayMono.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: state.totalProfit >= 0
                              ? colors.textPrimary
                              : colors.accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  TablerIcons.building_store,
                  color: colors.brand,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            TablerIcons.trending_up,
                            size: 14,
                            color: colors.accentGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            language.translate('network_total_revenue'),
                            style: textStyles.smallSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _networkAmount(
                        loading: state.isSummaryLoading,
                        child: Text(
                          _formatMoney(context, state.totalRevenue),
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: colors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            TablerIcons.trending_down,
                            size: 14,
                            color: colors.accentRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            language.translate('network_total_expenses'),
                            style: textStyles.smallSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _networkAmount(
                        loading: state.isSummaryLoading,
                        child: Text(
                          _formatMoney(context, state.totalExpenses),
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: colors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _networkAmount(
            loading: state.isSummaryLoading,
            child: Text(
              '${language.translate('network_operations_short')}: ${state.totalOperations}',
              style: textStyles.smallMono.copyWith(
                color: colors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSwitcher(BuildContext context, NetworkPeriod current) {
    final language = context.watch<LanguageCubit>();

    final periods = [
      LedgerSegmentItem(
        value: NetworkPeriod.today,
        label: language.translate('network_period_today'),
      ),
      LedgerSegmentItem(
        value: NetworkPeriod.month,
        label: language.translate('network_period_month'),
      ),
      LedgerSegmentItem(
        value: NetworkPeriod.all,
        label: language.translate('network_period_all'),
      ),
    ];

    return LedgerSegmentedControl<NetworkPeriod>(
      height: 36,
      segments: periods,
      selectedValue: current,
      onValueChanged: (p) {
        if (p == current) return;
        context.read<NetworkBloc>().add(LoadNetworkData(period: p));
      },
    );
  }

  Widget _buildStoreCard(
    BuildContext context,
    NetworkStore store,
    StoreSummaryRow summary, {
    required bool isCurrent,
    bool summaryLoading = false,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isOwner =
        authState is AuthAuthenticated && authState.role == UserRole.owner;
    final isEntering = _enteringStoreId == store.id;

    Future<void> enterStore() async {
      if (_enteringStoreId != null) return;
      setState(() => _enteringStoreId = store.id);
      try {
        final bloc = context.read<NetworkBloc>();
        bloc.add(EnterStoreRequested(storeId: store.id));
        final nextState = await bloc.stream.firstWhere(
          (s) => s is NetworkLoaded && !s.isSubmitting,
        );
        if (!context.mounted) return;
        if (nextState is NetworkLoaded &&
            nextState.actingStore?.id == store.id) {
          final acting = nextState.actingStore!;
          ExpiringRequestCache.invalidateAll();
          context.read<AuthBloc>().add(
            ActingStoreUpdated(storeId: acting.id, storeName: acting.name),
          );
          context.go('/dashboard');
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingError(e)),
            backgroundColor: colors.accentRed,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _enteringStoreId = null);
        }
      }
    }

    void openCurrentStore() {
      ExpiringRequestCache.invalidateAll();
      context.go('/dashboard');
    }

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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colors.accentGreen.withValues(alpha: 0.12)
                      : colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  TablerIcons.building_store,
                  color: isCurrent ? colors.accentGreen : colors.brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (store.location != null &&
                            store.location!.isNotEmpty) ...[
                          Icon(
                            TablerIcons.map_pin,
                            size: 13,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              store.location!,
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          Text(
                            '#${store.id}',
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colors.accentGreen.withValues(alpha: 0.12)
                      : (store.isActive
                            ? colors.brand.withValues(alpha: 0.08)
                            : colors.border.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCurrent
                      ? language.translate('network_current_badge')
                      : (store.isActive
                            ? language.translate('network_store_active')
                            : language.translate('network_store_inactive')),
                  style: textStyles.captionSans.copyWith(
                    color: isCurrent
                        ? colors.accentGreen
                        : (store.isActive
                              ? colors.brand
                              : colors.textSecondary),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(
                    TablerIcons.dots_vertical,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                  tooltip: language.translate('network_store_options'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: colors.border),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditStoreDialog(context, store);
                    } else if (val == 'reset_pwd') {
                      _showResetDirectorPasswordDialog(context, store);
                    } else if (val == 'delete') {
                      _showDeleteStoreDialog(context, store);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(TablerIcons.edit, size: 16, color: colors.brand),
                          const SizedBox(width: 8),
                          Text(
                            language.translate('network_store_edit'),
                            style: textStyles.bodySans.copyWith(fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'reset_pwd',
                      child: Row(
                        children: [
                          Icon(TablerIcons.key, size: 16, color: colors.brand),
                          const SizedBox(width: 8),
                          Text(
                            language.translate('network_director_reset_pwd'),
                            style: textStyles.bodySans.copyWith(fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            TablerIcons.trash,
                            size: 16,
                            color: colors.accentRed,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            language.translate('network_store_delete'),
                            style: textStyles.bodySans.copyWith(
                              fontSize: 13.5,
                              color: colors.accentRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceNested,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _networkAmount(
                        loading: summaryLoading,
                        child: _buildMetricCell(
                          context,
                          label: language.translate('network_revenue_short'),
                          value: _formatMoney(context, summary.revenue),
                          valueColor: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _networkAmount(
                        loading: summaryLoading,
                        child: _buildMetricCell(
                          context,
                          label: language.translate('network_expenses_short'),
                          value: _formatMoney(context, summary.expenses),
                          valueColor: colors.accentRed,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _networkAmount(
                        loading: summaryLoading,
                        child: _buildMetricCell(
                          context,
                          label: language.translate('network_profit_short'),
                          value: _formatMoney(context, summary.profit),
                          valueColor: summary.profit >= 0
                              ? colors.accentGreen
                              : colors.accentRed,
                          isBold: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCell(
                        context,
                        label: language.translate('network_users_short'),
                        value:
                            '${store.usersCount} ${language.translate('network_employees_suffix')}',
                        valueColor: colors.textPrimary,
                        icon: TablerIcons.users,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        TablerIcons.receipt,
                        size: 13,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      _networkAmount(
                        loading: summaryLoading,
                        child: Text(
                          '${language.translate('network_operations_short')}: ${summary.operationsCount}',
                          style: textStyles.smallMono.copyWith(
                            color: colors.textSecondary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (isCurrent)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: openCurrentStore,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.accentGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        TablerIcons.circle_check_filled,
                        size: 16,
                        color: colors.accentGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${language.translate('network_current_store_btn')} • ${language.translate('common_open')}',
                        style: textStyles.captionSans.copyWith(
                          color: colors.accentGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        TablerIcons.arrow_right,
                        size: 14,
                        color: colors.accentGreen,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!store.isActive)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null,
                child: Text(
                  language.translate('network_enter_disabled_hint'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _enteringStoreId != null ? null : enterStore,
                child: isEntering
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.surface,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            language.translate('network_enter_store_btn'),
                            style: textStyles.captionSans.copyWith(
                              color: colors.surface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            TablerIcons.arrow_right,
                            size: 16,
                            color: colors.surface,
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
    IconData? icon,
    bool isBold = false,
  }) {
    final textStyles = context.textStyles;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textStyles.captionSans.copyWith(
            color: colors.textSecondary,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                value,
                style: textStyles.bodyMono.copyWith(
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isNetworkSuccess(String msg) {
    final lower = msg.toLowerCase();
    if (msg.startsWith('error_') || lower.contains('exception')) {
      return false;
    }
    if (msg.startsWith('network_err')) return false;
    if (msg.startsWith('network_')) return true;
    return lower.contains('создан') ||
        lower.contains('обновл') ||
        lower.contains('удал') ||
        lower.contains('отключ') ||
        lower.contains('парол') ||
        lower.contains('директор');
  }

  Widget _buildEmptyStores(BuildContext context, {required bool isOwner}) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                TablerIcons.building_store,
                size: 32,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              language.translate('network_no_stores'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showCreateStoreDialog(context),
                icon: const Icon(TablerIcons.plus, size: 18),
                label: Text(language.translate('network_empty_cta')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 40),
            const SizedBox(height: 12),
            Text(
              language.translateMessage(message),
              style: textStyles.bodySans,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<NetworkBloc>().add(
                  const LoadNetworkData(forceRefresh: true),
                );
              },
              child: Text(language.translate('common_retry')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateStoreDialog(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final bloc = context.read<NetworkBloc>();
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final dirUserCtrl = TextEditingController();
    final dirPassCtrl = TextEditingController();
    final dirNameCtrl = TextEditingController();

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('network_new_store_title'),
      builder: (sheetContext, setState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: language.translate('network_store_name_label'),
                    hintText: language.translate('network_store_name_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locCtrl,
                  decoration: InputDecoration(
                    labelText: language.translate(
                      'network_store_location_label',
                    ),
                    hintText: language.translate('network_store_location_hint'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('network_director_section'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dirNameCtrl,
                  decoration: InputDecoration(
                    labelText: language.translate(
                      'network_director_fullname_label',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dirUserCtrl,
                  decoration: InputDecoration(
                    labelText: language.translate(
                      'network_director_username_label',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dirPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: language.translate(
                      'network_director_password_label',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            language.translate('network_create_name_required'),
                          ),
                        ),
                      );
                      return;
                    }
                    if (dirUserCtrl.text.trim().isNotEmpty &&
                        dirPassCtrl.text.trim().length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            language.translate('network_err_short_password'),
                          ),
                        ),
                      );
                      return;
                    }
                    bloc.add(
                      CreateStoreRequested(
                        input: StoreCreateInput(
                          name: nameCtrl.text.trim(),
                          location: locCtrl.text.trim().isNotEmpty
                              ? locCtrl.text.trim()
                              : null,
                          directorFullName: dirNameCtrl.text.trim().isNotEmpty
                              ? dirNameCtrl.text.trim()
                              : null,
                          directorUsername: dirUserCtrl.text.trim().isNotEmpty
                              ? dirUserCtrl.text.trim()
                              : null,
                          directorPassword: dirPassCtrl.text.trim().isNotEmpty
                              ? dirPassCtrl.text.trim()
                              : null,
                        ),
                      ),
                    );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Text(language.translate('common_create')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditStoreDialog(BuildContext context, NetworkStore store) {
    final language = context.read<LanguageCubit>();
    final bloc = context.read<NetworkBloc>();
    final nameCtrl = TextEditingController(text: store.name);
    final locCtrl = TextEditingController(text: store.location ?? '');
    var isActive = store.isActive;

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('network_store_edit_title'),
      builder: (sheetContext, setSheetState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: language.translate('network_store_name_label'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locCtrl,
                decoration: InputDecoration(
                  labelText: language.translate('network_store_location_label'),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                title: Text(
                  language.translate('network_store_status_active'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  language.translate('network_store_status_hint'),
                  style: const TextStyle(fontSize: 12),
                ),
                onChanged: (val) {
                  setSheetState(() => isActive = val);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  bloc.add(
                    UpdateStoreRequested(
                      storeId: store.id,
                      name: nameCtrl.text.trim(),
                      location: locCtrl.text.trim().isNotEmpty
                          ? locCtrl.text.trim()
                          : null,
                      isActive: isActive,
                    ),
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Text(language.translate('common_save')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showResetDirectorPasswordDialog(
    BuildContext context,
    NetworkStore store,
  ) {
    final language = context.read<LanguageCubit>();
    final bloc = context.read<NetworkBloc>();
    final passCtrl = TextEditingController();
    final userCtrl = TextEditingController();

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('network_director_reset_pwd_title'),
      builder: (sheetContext, setSheetState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${language.translate('login_store_label')}: ${store.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: userCtrl,
                decoration: InputDecoration(
                  labelText: language.translate(
                    'network_director_username_label',
                  ),
                  hintText: language.translate(
                    'network_director_username_hint',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: language.translate(
                    'network_director_new_pwd_label',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (passCtrl.text.trim().length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          language.translate('network_err_short_password'),
                        ),
                      ),
                    );
                    return;
                  }
                  bloc.add(
                    ResetDirectorPasswordRequested(
                      storeId: store.id,
                      username: userCtrl.text.trim().isEmpty
                          ? null
                          : userCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                    ),
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
                child: Text(
                  language.translate('network_director_reset_pwd_btn'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteStoreDialog(BuildContext context, NetworkStore store) {
    final language = context.read<LanguageCubit>();
    final bloc = context.read<NetworkBloc>();
    final colors = context.colors;

    showDialog<void>(
      context: context,
      builder: (dlgContext) => Theme(
        data: LedgerButtons.modalOverlay(dlgContext),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(language.translate('network_store_delete_confirm_title')),
          content: Text(
            language.translate(
              store.hasData
                  ? 'network_delete_has_data'
                  : 'network_delete_empty',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgContext).pop(),
              child: Text(language.translate('common_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dlgContext).pop();
                bloc.add(DeleteStoreRequested(storeId: store.id));
              },
              child: Text(
                language.translate(
                  store.hasData
                      ? 'network_disable_confirm'
                      : 'network_store_delete_btn',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
