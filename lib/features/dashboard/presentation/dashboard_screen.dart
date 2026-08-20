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
import '../../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../../features/dashboard/bloc/dashboard_event.dart';
import '../../../features/dashboard/bloc/dashboard_state.dart';
import '../../../features/dashboard/domain/finance_repository.dart';
import '../../../features/dashboard/domain/finance_model.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/ledger_spotlight.dart';
import '../../cash/presentation/sales_profit_card.dart';
import '../../assistant/presentation/ledger_advice_panel.dart';
import '../../notifications/presentation/notification_bell.dart';
import 'currency_board_card.dart';

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
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var _activated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_activated || !TickerMode.valuesOf(context).enabled) return;
    _activated = true;
    context.read<DashboardBloc>().add(LoadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    if (!_activated && !TickerMode.valuesOf(context).enabled) {
      return const SizedBox.shrink();
    }
    try {
      context.read<DashboardBloc>();
      return const DashboardView();
    } catch (_) {
      return BlocProvider<DashboardBloc>(
        create: (context) =>
            DashboardBloc(context.read<FinanceRepository>())
              ..add(LoadDashboardData()),
        child: const DashboardView(),
      );
    }
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DashboardSection? _openReport;

  void _openDashboardReport(DashboardSection section) {
    setState(() => _openReport = section);
    context.read<DashboardBloc>().add(LoadDashboardSection(section));
  }

  void _closeDashboardReport() {
    setState(() => _openReport = null);
  }

  String _reportTitle(LanguageCubit language, DashboardSection section) {
    return language.translate(switch (section) {
      DashboardSection.pnl => 'dashboard_tab_pnl',
      DashboardSection.planFact => 'dashboard_tab_plan_fact',
      DashboardSection.breakEven => 'dashboard_tab_break_even',
      DashboardSection.abc => 'dashboard_tab_abc',
      DashboardSection.accountsRates => 'dashboard_tab_accounts_rates',
      DashboardSection.clients => 'dashboard_tab_clients',
      DashboardSection.aiInsights => 'dashboard_tab_ai_insights',
    });
  }

  // Разделение тысяч для числовых сумм
  String _formatAmount(BuildContext context, double amount) {
    return formatLocalizedNumber(context, amount);
  }

  Future<void> _refreshDashboard(BuildContext context) {
    final completion = Completer<void>();
    final section = _openReport;
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
    final canWrite = context.select<AuthBloc, bool>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated &&
          state.role.canWrite(AppCapability.dashboard);
    });

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

        final loadedState = state is DashboardLoaded ? state : null;
        final currency = loadedState?.currency ?? 'TJS';

        final openReport = _openReport;
        return PopScope(
          canPop: openReport == null,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_openReport != null) _closeDashboardReport();
          },
          child: Scaffold(
            floatingActionButton:
                (openReport == DashboardSection.planFact &&
                    canWrite &&
                    loadedState != null)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      final period =
                          loadedState.planFact?.period ?? _defaultPlanPeriod();
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
                    title: openReport == null
                        ? languageCubit.translate('dashboard_title')
                        : _reportTitle(languageCubit, openReport),
                    titleWidget: openReport == null
                        ? Row(
                            children: [
                              Image.asset(
                                'assets/images/payk_icon.png',
                                height: 24,
                                fit: BoxFit.contain,
                                cacheWidth: 72,
                                filterQuality: FilterQuality.low,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  languageCubit.translate('dashboard_title'),
                                  style: textStyles.h1Sans.copyWith(
                                    fontSize: context.fontSize(22),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              IconButton(
                                tooltip: languageCubit.translate(
                                  'dashboard_back',
                                ),
                                onPressed: _closeDashboardReport,
                                icon: Icon(
                                  TablerIcons.arrow_left,
                                  color: colors.brand,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _reportTitle(languageCubit, openReport),
                                  style: textStyles.h1Sans.copyWith(
                                    fontSize: context.fontSize(20),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                    pinned: true,
                    floating: false,
                    snap: false,
                    actions: [
                      const NotificationBell(),
                      _buildCurrencySelector(context, currency),
                    ],
                  ),
                ];
              },
              body: loadedState == null
                  ? const DashboardOverviewShimmer()
                  : (openReport == null
                        ? _buildOverviewHome(context, loadedState, currency)
                        : _buildOpenedReport(openReport)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenedReport(DashboardSection section) {
    return switch (section) {
      DashboardSection.pnl => _buildLazyDashboardSection<PnlReport>(
        section: DashboardSection.pnl,
        select: (loaded) => loaded.pnl,
        contentBuilder: _buildPnlTab,
      ),
      DashboardSection.planFact => _buildLazyDashboardSection<PlanFactReport>(
        section: DashboardSection.planFact,
        select: (loaded) => loaded.planFact,
        contentBuilder: _buildPlanFactTab,
      ),
      DashboardSection.breakEven =>
        _buildLazyDashboardSection<BreakEvenAnalysis>(
          section: DashboardSection.breakEven,
          select: (loaded) => loaded.breakEven,
          contentBuilder: _buildBreakEvenTab,
        ),
      DashboardSection.abc => _buildLazyDashboardSection<AbcAnalysis>(
        section: DashboardSection.abc,
        select: (loaded) => loaded.abc,
        contentBuilder: _buildAbcTab,
      ),
      DashboardSection.accountsRates =>
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
      DashboardSection.clients =>
        _buildLazyDashboardSection<ClientAnalysisReport>(
          section: DashboardSection.clients,
          select: (loaded) => loaded.clients,
          contentBuilder: (context, data, currency) =>
              _buildClientsTab(context, data),
        ),
      DashboardSection.aiInsights =>
        _buildLazyDashboardSection<AiInsightsReport>(
          section: DashboardSection.aiInsights,
          select: (loaded) => loaded.aiInsights,
          contentBuilder: _buildAiInsightsTab,
        ),
    };
  }
}
