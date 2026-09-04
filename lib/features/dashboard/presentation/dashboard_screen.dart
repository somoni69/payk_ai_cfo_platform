import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/ledger_layout.dart';
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
import '../../../presentation/widgets/ledger_fab.dart';
import '../../../presentation/widgets/ledger_segmented_control.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/ledger_spotlight.dart';
import '../../cash/presentation/sales_profit_card.dart';
import '../../assistant/presentation/ledger_advice_panel.dart';
import '../../assistant/presentation/ledger_ai_assistant.dart';
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
part 'dashboard_tab_onec.dart';
part 'dashboard_chart.dart';

/// Входная точка экрана аналитики с безопасным внедрением DashboardBloc.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<DashboardBloc>();
      return const DashboardView();
    } catch (_) {
      return BlocProvider<DashboardBloc>(
        create: (context) =>
            DashboardBloc(context.read<FinanceRepository>())
              ..add(const LoadDashboardData()),
        child: const DashboardView(),
      );
    }
  }
}

// Разделение тысяч для числовых сумм
String _formatAmount(BuildContext context, double amount) {
  return formatLocalizedNumber(context, amount);
}

void _openDashboardReport(BuildContext context, DashboardSection section) {
  final bloc = context.read<DashboardBloc>();
  bloc.add(LoadDashboardSection(section));
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: DashboardReportScreen(section: section),
      ),
    ),
  );
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
    DashboardSection.onec => 'dashboard_tab_onec',
  });
}

Widget _buildOpenedReport(BuildContext context, DashboardSection section) {
  return switch (section) {
    DashboardSection.pnl => _buildLazyDashboardSection<PnlReport>(
      section: DashboardSection.pnl,
      select: (loaded) => loaded.pnl,
      contentBuilder: _buildPnlTab,
      shimmer: const DashboardSectionShimmer(kind: DashboardShimmerKind.pnl),
    ),
    DashboardSection.planFact => _buildLazyDashboardSection<PlanFactReport>(
      section: DashboardSection.planFact,
      select: (loaded) => loaded.planFact,
      contentBuilder: _buildPlanFactTab,
      shimmer: const DashboardSectionShimmer(
        kind: DashboardShimmerKind.planFact,
      ),
    ),
    DashboardSection.breakEven => _buildLazyDashboardSection<BreakEvenAnalysis>(
      section: DashboardSection.breakEven,
      select: (loaded) => loaded.breakEven,
      contentBuilder: _buildBreakEvenTab,
      shimmer: const DashboardSectionShimmer(
        kind: DashboardShimmerKind.breakEven,
      ),
    ),
    DashboardSection.abc => _buildLazyDashboardSection<AbcAnalysis>(
      section: DashboardSection.abc,
      select: (loaded) => loaded.abc,
      contentBuilder: _buildAbcTab,
      shimmer: const DashboardSectionShimmer(kind: DashboardShimmerKind.abc),
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
        shimmer: const DashboardSectionShimmer(
          kind: DashboardShimmerKind.accounts,
        ),
      ),
    DashboardSection.clients =>
      _buildLazyDashboardSection<ClientAnalysisReport>(
        section: DashboardSection.clients,
        select: (loaded) => loaded.clients,
        contentBuilder: (context, data, currency) =>
            _buildClientsTab(context, data),
        shimmer: const DashboardSectionShimmer(
          kind: DashboardShimmerKind.clients,
        ),
      ),
    DashboardSection.aiInsights => _buildLazyDashboardSection<AiInsightsReport>(
      section: DashboardSection.aiInsights,
      select: (loaded) => loaded.aiInsights,
      contentBuilder: _buildAiInsightsTab,
      shimmer: const DashboardSectionShimmer(kind: DashboardShimmerKind.ai),
    ),
    DashboardSection.onec => _buildLazyDashboardSection<_OneCData>(
      section: DashboardSection.onec,
      select: (loaded) {
        final onec = loaded.onec;
        final targets = loaded.onecTargets;
        return onec == null || targets == null
            ? null
            : _OneCData(onec, targets);
      },
      contentBuilder: (context, data, currency) {
        return _buildOneCTab(context, data.onec, data.targets);
      },
      shimmer: const DashboardSectionShimmer(kind: DashboardShimmerKind.onec),
    ),
  };
}

/// Полноэкранный детальный просмотр финансового отчета (P&L, План-Факт, Безубыточность и т.д.).
/// Открывается поверх root navigator, скрывая bottomappbar и NotificationBell.
class DashboardReportScreen extends StatelessWidget {
  final DashboardSection section;

  const DashboardReportScreen({super.key, required this.section});

  Future<void> _refreshReport(BuildContext context) {
    final bloc = context.read<DashboardBloc>();
    bloc.add(LoadDashboardSection(section, forceRefresh: true));
    return bloc.stream.firstWhere((state) {
      if (state is! DashboardLoaded) return false;
      return !state.loadingSections.contains(section);
    });
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

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final currency = state is DashboardLoaded ? state.currency : 'TJS';
        final loadedState = state is DashboardLoaded ? state : null;

        return Scaffold(
          backgroundColor: colors.background,
          floatingActionButton:
              (section == DashboardSection.planFact &&
                  canWrite &&
                  loadedState != null)
              ? LedgerFab(
                  heroTag: null,
                  onPressed: () {
                    final period =
                        loadedState.planFact?.period ?? _defaultPlanPeriod();
                    _showCreatePlanSheet(context, period);
                  },
                  icon: TablerIcons.plus,
                  label: languageCubit.translate('dashboard_plan_add'),
                )
              : null,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  leading: const BackButton(),
                  title: Text(
                    _reportTitle(languageCubit, section),
                    style: textStyles.h2Sans.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  actions: [
                    _buildCurrencySelector(context, currency),
                    const SizedBox(width: 8),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: colors.border),
                  ),
                ),
              ];
            },
            body: RefreshIndicator(
              onRefresh: () => _refreshReport(context),
              child: _buildOpenedReport(context, section),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _refreshDashboard(BuildContext context) {
  final bloc = context.read<DashboardBloc>();
  bloc.add(const LoadDashboardData(forceRefresh: true));
  return bloc.stream.firstWhere((state) => state is! DashboardLoading);
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<DashboardBloc>();
      if (bloc.state is! DashboardLoaded) {
        bloc.add(const LoadDashboardData());
      }
    });
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

        return Scaffold(
          floatingActionButtonLocation: kLedgerShellFabLocation,
          floatingActionButton: const LedgerAiFloatingButton(),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  title: Row(
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
                            fontSize: context.fontSize(20),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    const NotificationBell(),
                    _buildCurrencySelector(context, currency),
                    const SizedBox(width: 6),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: colors.border),
                  ),
                ),
              ];
            },
            body: loadedState == null
                ? const DashboardOverviewShimmer()
                : _buildOverviewHome(context, loadedState, currency),
          ),
        );
      },
    );
  }
}
