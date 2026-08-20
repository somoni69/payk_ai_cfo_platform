import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/crm/bloc/crm_bloc.dart';
import '../../../features/crm/bloc/crm_event.dart';
import '../../../features/crm/bloc/crm_state.dart';
import '../../../features/crm/domain/crm_models.dart';
import '../../../features/crm/domain/crm_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import 'crm_funnel.dart';
import 'crm_labels.dart';
import 'crm_sheets.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmBloc>(
      create: (context) =>
          CrmBloc(context.read<CrmRepository>())..add(const LoadCrmData()),
      child: const CrmView(),
    );
  }
}

class CrmView extends StatefulWidget {
  const CrmView({super.key});

  @override
  State<CrmView> createState() => _CrmViewState();
}

class _CrmViewState extends State<CrmView> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  static const _tabCount = 6;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabCount, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) {
    final done = Completer<void>();
    context.read<CrmBloc>().add(
      LoadCrmData(forceRefresh: true, completion: done),
    );
    return done.future;
  }

  UserRole? _role(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.role : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final role = _role(context);
    final canWrite = role?.canWrite(AppCapability.crm) ?? false;
    final canDelete = role?.canDelete(AppCapability.crm) ?? false;

    return Scaffold(
      floatingActionButton: canWrite && (_tabs.index == 0 || _tabs.index == 1)
          ? FloatingActionButton.extended(
              onPressed: () {
                final state = context.read<CrmBloc>().state;
                if (state is! CrmLoaded) return;
                if (_tabs.index == 0) {
                  showCrmClientForm(context);
                } else {
                  showCrmDealForm(
                    context,
                    clients: state.pickClients.isNotEmpty
                        ? state.pickClients
                        : state.clients,
                  );
                }
              },
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
              icon: Icon(
                _tabs.index == 0 ? TablerIcons.user_plus : TablerIcons.plus,
              ),
              label: Text(
                language.translate(
                  _tabs.index == 0 ? 'crm_new_client' : 'crm_new_deal',
                ),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) {
          return [
            LedgerCollapsingHeader(
              title: language.translate('crm_title'),
              titleWidget: Text(
                language.translate('crm_title'),
                style: textStyles.h1Sans.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              pinned: true,
              floating: false,
              snap: false,
              bottom: LedgerTabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  Tab(text: language.translate('crm_tab_clients')),
                  Tab(text: language.translate('crm_tab_funnel')),
                  Tab(text: language.translate('crm_tab_loyalty')),
                  Tab(text: language.translate('crm_tab_reactivation')),
                  Tab(text: language.translate('crm_tab_churn')),
                  Tab(text: language.translate('crm_tab_birthdays')),
                ],
              ),
            ),
          ];
        },
        body: BlocListener<CrmBloc, CrmState>(
          listenWhen: (p, c) {
            if (c is! CrmLoaded) return false;
            return c.errorMessage != null || c.successMessage != null;
          },
          listener: (context, state) {
            if (state is! CrmLoaded) return;
            final msg = state.errorMessage ?? state.successMessage;
            if (msg == null) return;
            final isError = state.errorMessage != null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(language.resolveMessage(msg)),
                backgroundColor: isError
                    ? colors.accentRed
                    : colors.accentGreen,
              ),
            );
            context.read<CrmBloc>().add(const ClearCrmFeedback());
          },
          child: BlocBuilder<CrmBloc, CrmState>(
            builder: (context, state) {
              if (state is CrmLoading) {
                return const _CrmSkeleton();
              }
              if (state is CrmError) {
                return _ErrorBody(
                  message: language.resolveMessage(state.message),
                  onRetry: () =>
                      context.read<CrmBloc>().add(const LoadCrmData()),
                );
              }
              if (state is! CrmLoaded) return const SizedBox.shrink();

              return Column(
                children: [
                  if (state.isRefreshing) const LinearProgressIndicator(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _ClientsTab(
                          state: state,
                          canWrite: canWrite,
                          canDelete: canDelete,
                          searchCtrl: _searchCtrl,
                          onSearch: (q) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 350),
                              () {
                                context.read<CrmBloc>().add(
                                  ClientFiltersChanged(query: q),
                                );
                              },
                            );
                          },
                          onRefresh: () => _refresh(context),
                        ),
                        CrmFunnelBoard(
                          state: state,
                          canWrite: canWrite,
                          canDelete: canDelete,
                          onRefresh: () => _refresh(context),
                        ),
                        _LoyaltyTab(
                          state: state,
                          canWrite: canWrite,
                          onRefresh: () => _refresh(context),
                        ),
                        _ReactivationTab(
                          state: state,
                          canWrite: canWrite,
                          onRefresh: () => _refresh(context),
                        ),
                        _ChurnTab(
                          state: state,
                          canWrite: canWrite,
                          onRefresh: () => _refresh(context),
                        ),
                        _BirthdaysTab(
                          state: state,
                          onRefresh: () => _refresh(context),
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
    );
  }
}

class _CrmSkeleton extends StatelessWidget {
  const _CrmSkeleton();

  @override
  Widget build(BuildContext context) {
    return const CrmOverviewShimmer();
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final CrmStatsData stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    Widget cell(String label, String value, {String? hint, Color? accent}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textStyles.smallSans.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: textStyles.bodyMono.copyWith(
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: textStyles.smallSans.copyWith(
                    color: colors.textTooltip,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Web StatsBar: clients, LTV(+ROI), reactivation, churn.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          Row(
            children: [
              cell(
                language.translate('crm_stat_total_clients'),
                '${stats.clientsTotal}',
                hint: language.translate(
                  'crm_stat_active_hint',
                  params: {'n': stats.activeClients},
                ),
              ),
              const SizedBox(width: 8),
              cell(
                language.translate('crm_stat_total_ltv'),
                oCcy.format(stats.ltvTotal),
                hint: stats.roi == null
                    ? '${language.translate('crm_stat_total_cac')}: ${oCcy.format(stats.cacTotal)}'
                    : '${language.translate('crm_stats_bar_roi')}: ${oCcy.format(stats.roi!)}',
                accent: colors.accentGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              cell(
                language.translate('crm_stat_reactivation'),
                '${stats.reactivationCount}',
                hint: language.translate('crm_stat_reactivation_hint'),
                accent: colors.brand,
              ),
              const SizedBox(width: 8),
              cell(
                language.translate('crm_stat_churn'),
                '${stats.churnCount}',
                hint: language.translate('crm_stat_churn_hint'),
                accent: colors.accentRed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab({
    required this.state,
    required this.canWrite,
    required this.canDelete,
    required this.searchCtrl,
    required this.onSearch,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final bool canDelete;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final pages = state.clientsSize <= 0
        ? 1
        : ((state.clientsTotal + state.clientsSize - 1) ~/ state.clientsSize)
              .clamp(1, 9999);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _StatsBar(stats: state.stats),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchCtrl,
              style: textStyles.bodySans,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: language.translate('crm_search_placeholder'),
                prefixIcon: const Icon(TablerIcons.search, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final options = crmLoyaltyOptions(language);
                final selectedValue = state.clientFilters.level ?? '';
                final selected = options.firstWhere(
                  (o) => o.value == selectedValue,
                  orElse: () => options.first,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      language.translate('crm_filter_all_levels'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ExpansibleWidget<({String value, String label})>.selection(
                      key: ValueKey('crm-level-$selectedValue'),
                      title: Text(
                        selected.label,
                        style: textStyles.bodySans.copyWith(
                          color: selectedValue.isEmpty
                              ? colors.textTooltip
                              : colors.textPrimary,
                        ),
                      ),
                      items: options,
                      selectedValue: selected,
                      itemLabelBuilder: (o) => o.label,
                      onSelected: (o) {
                        context.read<CrmBloc>().add(
                          ClientFiltersChanged(level: o.value),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (state.clients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        language.translate('crm_no_clients'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textTooltip,
                        ),
                      ),
                    ),
                  )
                else
                  ...state.clients.map((client) {
                    final lc = crmLoyaltyColors(colors, client.loyaltyLevel);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => showCrmClientDetail(context, client),
                        child: LedgerCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      client.fullName,
                                      style: textStyles.bodySans.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  LedgerPill(
                                    text: crmLoyaltyLabel(
                                      language,
                                      client.loyaltyLevel,
                                    ),
                                    backgroundColor: lc.bg,
                                    textColor: lc.fg,
                                  ),
                                  if (client.churnRisk) ...[
                                    const SizedBox(width: 6),
                                    LedgerPill(
                                      text: language.translate(
                                        'crm_churn_risk',
                                      ),
                                      backgroundColor: colors.accentRed
                                          .withValues(alpha: 0.08),
                                      textColor: colors.accentRed,
                                    ),
                                  ],
                                ],
                              ),
                              if (client.phone != null ||
                                  client.email != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  client.phone ?? client.email!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'LTV ${oCcy.format(client.totalSpent)}',
                                      style: textStyles.smallMono.copyWith(
                                        color: colors.accentGreen,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${language.translate('crm_bonus_points')}: ${oCcy.format(client.bonusPoints)}',
                                      style: textStyles.smallMono.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      client.roi == null
                                          ? 'ROI —'
                                          : 'ROI ${oCcy.format(client.roi!)}×',
                                      style: textStyles.smallMono.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${language.translate('crm_last_purchase')}: ${client.lastPurchaseAt == null ? '—' : formatLocalizedDateTime(context, client.lastPurchaseAt!, style: LocalizedDateTimeStyle.date)}',
                                style: textStyles.smallSans.copyWith(
                                  color: colors.textTooltip,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                if (pages > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: state.clientsPage <= 1
                            ? null
                            : () => context.read<CrmBloc>().add(
                                ClientFiltersChanged(
                                  page: state.clientsPage - 1,
                                ),
                              ),
                        child: Text(language.translate('crm_prev_page')),
                      ),
                      Text(
                        '${state.clientsPage} / $pages',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: state.clientsPage >= pages
                            ? null
                            : () => context.read<CrmBloc>().add(
                                ClientFiltersChanged(
                                  page: state.clientsPage + 1,
                                ),
                              ),
                        child: Text(language.translate('crm_next_page')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyTab extends StatelessWidget {
  const _LoyaltyTab({
    required this.state,
    required this.canWrite,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  String _clientName(String id) {
    for (final c in state.pickClients) {
      if (c.id == id) return c.fullName;
    }
    for (final c in state.clients) {
      if (c.id == id) return c.fullName;
    }
    return '#$id';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);
    final pick = state.pickClients.isNotEmpty
        ? state.pickClients
        : state.clients;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            language.translate('crm_loyalty_summary'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          if (state.loyaltySummary.isEmpty)
            Text(
              language.translate('crm_no_loyalty'),
              style: textStyles.bodySans.copyWith(color: colors.textTooltip),
            )
          else
            ...state.loyaltySummary.map((row) {
              final lc = crmLoyaltyColors(colors, row.level);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LedgerPill(
                        text: crmLoyaltyLabel(language, row.level),
                        backgroundColor: lc.bg,
                        textColor: lc.fg,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        language.translate(
                          'crm_loyalty_clients_count',
                          params: {'count': row.clients},
                        ),
                        style: textStyles.captionSans,
                      ),
                      Text(
                        language.translate(
                          'crm_loyalty_spent',
                          params: {'amount': oCcy.format(row.totalSpent)},
                        ),
                        style: textStyles.smallMono,
                      ),
                      Text(
                        language.translate(
                          'crm_loyalty_bonus_total',
                          params: {'amount': oCcy.format(row.bonusPoints)},
                        ),
                        style: textStyles.smallMono,
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            language.translate('crm_loyalty_history_title'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final options = <({String value, String label})>[
                (
                  value: '',
                  label: language.translate('crm_loyalty_all_clients'),
                ),
                ...pick.map((c) => (value: c.id, label: c.fullName)),
              ];
              final selectedId = state.loyaltyFilterClientId ?? '';
              final selected = options.firstWhere(
                (o) => o.value == selectedId,
                orElse: () => options.first,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    language.translate('crm_loyalty_filter_client'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpansibleWidget<({String value, String label})>.selection(
                    key: ValueKey('crm-loyalty-filter-$selectedId'),
                    title: Text(
                      selected.label,
                      style: textStyles.bodySans.copyWith(
                        color: selectedId.isEmpty
                            ? colors.textTooltip
                            : colors.textPrimary,
                      ),
                    ),
                    items: options,
                    selectedValue: selected,
                    itemLabelBuilder: (o) => o.label,
                    onSelected: (o) {
                      context.read<CrmBloc>().add(
                        LoyaltyHistoryFilterChanged(
                          o.value.isEmpty ? null : o.value,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          if (canWrite && pick.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => showCrmBonusSheet(context, clients: pick),
              icon: const Icon(TablerIcons.gift, size: 18),
              label: Text(language.translate('crm_add_bonus')),
            ),
          ],
          const SizedBox(height: 12),
          if (state.loyaltyTxnsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.loyaltyTxns.isEmpty)
            Text(
              language.translate('crm_no_history'),
              style: textStyles.captionSans.copyWith(color: colors.textTooltip),
            )
          else
            ...state.loyaltyTxns.map((t) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _clientName(t.clientId),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              t.reason?.isNotEmpty == true
                                  ? t.reason!
                                  : formatLocalizedDateTime(
                                      context,
                                      t.createdAt,
                                      style: LocalizedDateTimeStyle.dateTime,
                                    ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        oCcy.format(t.points),
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w500,
                          color: t.points >= 0
                              ? colors.accentGreen
                              : colors.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (state.loyaltyTxnPage * 30 < state.loyaltyTxnTotal) ...[
            const SizedBox(height: 8),
            if (state.loyaltyTxnsLoadingMore)
              const Center(child: CircularProgressIndicator())
            else
              OutlinedButton(
                onPressed: () =>
                    context.read<CrmBloc>().add(const LoadMoreLoyaltyTxns()),
                child: Text(language.translate('crm_loyalty_load_more')),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReactivationTab extends StatelessWidget {
  const _ReactivationTab({
    required this.state,
    required this.canWrite,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: state.reactivation.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      language.translate('crm_no_reactivation'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textTooltip,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.reactivation.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = state.reactivation[i];
                return LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (c.phone != null)
                        Text(
                          c.phone!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      Text(
                        'LTV ${oCcy.format(c.totalSpent)} TJS',
                        style: textStyles.smallMono,
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => showCrmSmsSheet(context, c),
                          icon: const Icon(TablerIcons.mail, size: 18),
                          label: Text(language.translate('crm_send_sms')),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ChurnTab extends StatelessWidget {
  const _ChurnTab({
    required this.state,
    required this.canWrite,
    required this.onRefresh,
  });

  final CrmLoaded state;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.churnAdvice != null) ...[
            LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.translate('crm_ai_advice'),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.accentAmber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(state.churnAdvice!.advice, style: textStyles.bodySans),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.churnAnalyzing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (state.churn.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  language.translate('crm_no_churn'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            )
          else
            ...state.churn.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.fullName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          LedgerPill(
                            text: language.translate('crm_churn_risk'),
                            backgroundColor: colors.accentRed.withValues(
                              alpha: 0.08,
                            ),
                            textColor: colors.accentRed,
                          ),
                        ],
                      ),
                      Text(
                        'LTV ${oCcy.format(c.totalSpent)} TJS',
                        style: textStyles.smallMono,
                      ),
                      if (canWrite) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.read<CrmBloc>().add(
                            AnalyzeChurnRequested(c.id),
                          ),
                          icon: const Icon(TablerIcons.brain, size: 18),
                          label: Text(language.translate('crm_ai_analyze')),
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
}

class _BirthdaysTab extends StatelessWidget {
  const _BirthdaysTab({required this.state, required this.onRefresh});

  final CrmLoaded state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: state.birthdays.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      language.translate('crm_no_birthdays'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.textTooltip,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.birthdays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = state.birthdays[i];
                return LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(TablerIcons.cake, color: colors.brand, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.fullName,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              language.translate(
                                'crm_birthday_in_days',
                                params: {'days': b.daysUntil},
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            if (b.turning != null)
                              Text(
                                language.translate(
                                  'crm_turning',
                                  params: {'age': b.turning},
                                ),
                                style: textStyles.smallMono,
                              ),
                          ],
                        ),
                      ),
                      if (b.phone != null)
                        Text(
                          b.phone!,
                          style: textStyles.smallMono.copyWith(
                            color: colors.textTooltip,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.alert_circle, size: 48, color: colors.accentRed),
            const SizedBox(height: 16),
            Text(
              message,
              style: textStyles.bodySans,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(language.translate('crm_retry')),
            ),
          ],
        ),
      ),
    );
  }
}
