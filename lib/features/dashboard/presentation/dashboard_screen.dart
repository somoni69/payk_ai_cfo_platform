import 'dart:async';
import 'dart:ui' as ui;
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
import '../../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../../features/dashboard/bloc/dashboard_event.dart';
import '../../../features/dashboard/bloc/dashboard_state.dart';
import '../../../features/dashboard/domain/finance_repository.dart';
import '../../../features/dashboard/domain/finance_model.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_ai_card.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';

part 'dashboard_sections.dart';
part 'dashboard_tab_pnl.dart';
part 'dashboard_tab_plan_fact.dart';
part 'dashboard_tab_break_even.dart';
part 'dashboard_tab_abc.dart';
part 'dashboard_tab_accounts.dart';
part 'dashboard_tab_clients.dart';
part 'dashboard_tab_ai.dart';
part 'dashboard_chart.dart';

/// Входная точка экрана аналитики с внедрением DashboardBloc.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>(
      create: (context) =>
          DashboardBloc(context.read<FinanceRepository>())
            ..add(LoadDashboardData()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (!mounted || nextIndex == _activeTabIndex) return;
    setState(() {
      _activeTabIndex = nextIndex;
    });
    final section = _sectionForTab(nextIndex);
    if (section != null) {
      context.read<DashboardBloc>().add(LoadDashboardSection(section));
    }
  }

  DashboardSection? _sectionForTab(int index) {
    return switch (index) {
      1 => DashboardSection.pnl,
      2 => DashboardSection.planFact,
      3 => DashboardSection.breakEven,
      4 => DashboardSection.abc,
      5 => DashboardSection.accountsRates,
      6 => DashboardSection.clients,
      7 => DashboardSection.aiInsights,
      _ => null,
    };
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  // Разделение тысяч для числовых сумм
  String _formatAmount(BuildContext context, double amount) {
    return formatLocalizedNumber(context, amount);
  }

  Future<void> _refreshDashboard(BuildContext context) {
    final completion = Completer<void>();
    final section = _sectionForTab(_tabController.index);
    if (section == null) {
      context.read<DashboardBloc>().add(
        LoadDashboardData(forceRefresh: true, completion: completion),
      );
    } else {
      context.read<DashboardBloc>().add(
        LoadDashboardSection(
          section,
          forceRefresh: true,
          completion: completion,
        ),
      );
    }
    return completion.future;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.watch<LanguageCubit>();

    return BlocConsumer<DashboardBloc, DashboardState>(
      listenWhen: (previous, current) =>
          current is DashboardLoaded &&
          current.overviewError != null &&
          (previous is! DashboardLoaded ||
              previous.overviewError != current.overviewError),
      listener: (context, state) {
        final message = (state as DashboardLoaded).overviewError;
        if (message == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(languageCubit.translateMessage(message))),
        );
      },
      buildWhen: (previous, current) {
        if (previous is DashboardLoaded && current is DashboardLoaded) {
          return previous.metrics != current.metrics ||
              previous.history != current.history ||
              previous.currency != current.currency;
        }
        return previous.runtimeType != current.runtimeType;
      },
      builder: (context, state) {
        if (state is DashboardLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is DashboardError) {
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
                      languageCubit.translateMessage(state.message),
                      style: textStyles.bodySans,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<DashboardBloc>().add(LoadDashboardData());
                      },
                      child: Text(languageCubit.translate('dashboard_retry')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is DashboardLoaded) {
          final m = state.metrics;
          final currency = state.currency;

          final authState = context.watch<AuthBloc>().state;
          final canWrite = authState is AuthAuthenticated &&
              authState.role.canWrite(AppCapability.dashboard);

          return Scaffold(
            floatingActionButton: (_activeTabIndex == 2 && canWrite)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      final period =
                          state.planFact?.period ?? _defaultPlanPeriod();
                      _showCreatePlanSheet(context, period);
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
                    icon: const Icon(TablerIcons.plus),
                    label: Text(
                      languageCubit.translate('dashboard_plan_add'),
                      style: textStyles.bodySans.copyWith(
                        color: colors.surface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  LedgerCollapsingHeader(
                    title: languageCubit.translate('dashboard_title'),
                    titleWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/payk_icon.png',
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            languageCubit.translate('dashboard_title'),
                            style: textStyles.h1Sans.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    pinned: true,
                    floating: true,
                    snap: true,
                    actions: [_buildCurrencySelector(context, state.currency)],
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: true,
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
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_overview',
                          ),
                        ),
                        Tab(text: languageCubit.translate('dashboard_tab_pnl')),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_plan_fact',
                          ),
                        ),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_break_even',
                          ),
                        ),
                        Tab(text: languageCubit.translate('dashboard_tab_abc')),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_accounts_rates',
                          ),
                        ),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_clients',
                          ),
                        ),
                        Tab(
                          text: languageCubit.translate(
                            'dashboard_tab_ai_insights',
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: () => _refreshDashboard(context),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AI Рекомендация (MOB-04 / FIN-11)
                            LedgerAICard(
                              title: languageCubit.translate(
                                'dashboard_daily_recommendation_title',
                              ),
                              content: languageCubit.translate(
                                'dashboard_daily_recommendation_content',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Сетка 6 ключевых цифр
                            Text(
                              languageCubit.translate(
                                'dashboard_key_metrics_title',
                              ),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildMetricsGrid(m, currency),
                            const SizedBox(height: 20),

                            // Реальный график движения денежных средств
                            Text(
                              languageCubit.translate(
                                'dashboard_cash_flow_30_days_title',
                              ),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildChart(state.history, currency),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildLazyDashboardSection<PnlReport>(
                    section: DashboardSection.pnl,
                    select: (loaded) => loaded.pnl,
                    contentBuilder: _buildPnlTab,
                  ),
                  _buildLazyDashboardSection<PlanFactReport>(
                    section: DashboardSection.planFact,
                    select: (loaded) => loaded.planFact,
                    contentBuilder: _buildPlanFactTab,
                  ),
                  _buildLazyDashboardSection<BreakEvenAnalysis>(
                    section: DashboardSection.breakEven,
                    select: (loaded) => loaded.breakEven,
                    contentBuilder: _buildBreakEvenTab,
                  ),
                  _buildLazyDashboardSection<AbcAnalysis>(
                    section: DashboardSection.abc,
                    select: (loaded) => loaded.abc,
                    contentBuilder: _buildAbcTab,
                  ),
                  _buildLazyDashboardSection<_AccountsRatesData>(
                    section: DashboardSection.accountsRates,
                    select: (loaded) {
                      final accounts = loaded.bankAccounts;
                      final rates = loaded.rates;
                      return accounts == null || rates == null
                          ? null
                          : _AccountsRatesData(accounts, rates);
                    },
                    contentBuilder: (context, data, currency) {
                      return _buildAccountsRatesTab(
                        context,
                        data.accounts,
                        data.rates,
                        currency,
                      );
                    },
                  ),
                  _buildLazyDashboardSection<ClientAnalysisReport>(
                    section: DashboardSection.clients,
                    select: (loaded) => loaded.clients,
                    contentBuilder: (context, data, currency) =>
                        _buildClientsTab(context, data),
                  ),
                  _buildLazyDashboardSection<AiInsightsReport>(
                    section: DashboardSection.aiInsights,
                    select: (loaded) => loaded.aiInsights,
                    contentBuilder: _buildAiInsightsTab,
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
