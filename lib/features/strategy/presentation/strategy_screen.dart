import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/strategy/bloc/strategy_bloc.dart';
import '../../../features/strategy/bloc/strategy_event.dart';
import '../../../features/strategy/bloc/strategy_state.dart';
import '../../../features/strategy/domain/strategy_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

enum StrategySection {
  whatIf,
  marketing,
  matrices,
  macro,
  news,
  scenarios,
  summary,
}

String _strategySectionTitle(LanguageCubit language, StrategySection section) {
  return language.translate(switch (section) {
    StrategySection.whatIf => 'strategy_tab_whatif',
    StrategySection.marketing => 'strategy_tab_marketing',
    StrategySection.matrices => 'strategy_tab_matrices',
    StrategySection.macro => 'strategy_tab_macro',
    StrategySection.news => 'strategy_tab_news',
    StrategySection.scenarios => 'strategy_tab_scenarios',
    StrategySection.summary => 'strategy_tab_summary',
  });
}

String _currentQuarter() {
  final now = DateTime.now();
  final year = now.year;
  final quarter = ((now.month - 1) ~/ 3) + 1;
  return '$year-Q$quarter';
}

void _openStrategySection(BuildContext context, StrategySection section) {
  final bloc = context.read<StrategyBloc>();
  switch (section) {
    case StrategySection.matrices:
      bloc.add(const LoadStrategicAnalyses('swot'));
      break;
    case StrategySection.macro:
      bloc.add(const LoadMacroIndicators());
      break;
    case StrategySection.news:
      bloc.add(const LoadNews());
      break;
    case StrategySection.scenarios:
      bloc.add(LoadScenarios(quarter: _currentQuarter()));
      break;
    case StrategySection.summary:
      bloc.add(const LoadDailySummary());
      break;
    default:
      break;
  }

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: StrategySectionScreen(section: section),
      ),
    ),
  );
}

class StrategyScreen extends StatelessWidget {
  const StrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<StrategyBloc>(
      create: (context) => StrategyBloc(context.read<StrategyRepository>())
        ..add(const LoadDailySummary())
        ..add(LoadScenarios(quarter: _currentQuarter())),
      child: const StrategyView(),
    );
  }
}

class StrategyView extends StatefulWidget {
  const StrategyView({super.key});

  @override
  State<StrategyView> createState() => _StrategyViewState();
}

class _StrategyViewState extends State<StrategyView> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          locale.translate('strategy_title'),
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
      body: BlocListener<StrategyBloc, StrategyState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null &&
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(locale.translateMessage(state.errorMessage!)),
                backgroundColor: colors.accentRed,
              ),
            );
          }
        },
        child: BlocBuilder<StrategyBloc, StrategyState>(
          buildWhen: (previous, current) =>
              previous.summaryLoaded != current.summaryLoaded ||
              previous.scenariosLoaded != current.scenariosLoaded ||
              previous.isSummaryLoading != current.isSummaryLoading ||
              previous.isScenariosLoading != current.isScenariosLoading ||
              previous.dailySummary != current.dailySummary ||
              previous.scenarios != current.scenarios,
          builder: (context, state) {
            if (!state.summaryLoaded &&
                !state.scenariosLoaded &&
                (state.isSummaryLoading || state.isScenariosLoading)) {
              return const StrategyOverviewShimmer();
            }
            return _buildStrategyOverviewHub(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildStrategyOverviewHub(BuildContext context, StrategyState state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    final hasScenarios = state.scenarios.isNotEmpty;
    final summaryText = state.dailySummary?.summary;

    return RefreshIndicator(
      onRefresh: () async {
        final bloc = context.read<StrategyBloc>();
        bloc.add(const LoadDailySummary(forceRefresh: true));
        bloc.add(LoadScenarios(quarter: _currentQuarter(), forceRefresh: true));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: AI CFO Strategy Radar
          Container(
            padding: const EdgeInsets.all(18),
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
                        locale.translate('strategy_hero_title'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TablerIcons.brain,
                            size: 13,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentQuarter(),
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  locale.translate('strategy_hero_status'),
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      TablerIcons.chart_dots_3,
                      size: 16,
                      color: colors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${state.scenarios.length} ${locale.translate('strategy_tab_scenarios').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• AI What-If & SWOT готовы',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 12),


          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('strategy_tab_whatif'),
                  subtitle: locale.translate('strategy_whatif_hint'),
                  icon: TablerIcons.help,
                  onTap: () =>
                      _openStrategySection(context, StrategySection.whatIf),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('strategy_tab_marketing'),
                  subtitle: locale.translate('strategy_marketing_hint'),
                  icon: TablerIcons.sparkles,
                  onTap: () =>
                      _openStrategySection(context, StrategySection.marketing),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('strategy_tab_matrices'),
                  subtitle: 'SWOT, PESTEL, BCG',
                  icon: TablerIcons.layout_grid,
                  onTap: () =>
                      _openStrategySection(context, StrategySection.matrices),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('strategy_tab_macro'),
                  subtitle: locale.translate('strategy_tab_macro'),
                  icon: TablerIcons.chart_arrows_vertical,
                  onTap: () =>
                      _openStrategySection(context, StrategySection.macro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Secondary 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('strategy_tab_news'),
                  subtitle: locale.translate('strategy_tab_news'),
                  icon: TablerIcons.news,
                  onTap: () =>
                      _openStrategySection(context, StrategySection.news),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('strategy_tab_scenarios'),
                  subtitle: '${state.scenarios.length} сценариев',
                  icon: TablerIcons.target_arrow,
                  onTap: () =>
                      _openStrategySection(context, StrategySection.scenarios),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6. Recent AI Daily Summary Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('strategy_recent_summary'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openStrategySection(context, StrategySection.summary),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('strategy_full_summary'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: summaryText != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            TablerIcons.file_text,
                            size: 16,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            state.dailySummary?.date ?? '',
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summaryText,
                        style: textStyles.bodySans.copyWith(
                          fontSize: 14,
                          height: 1.4,
                          color: colors.textPrimary,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Text(
                    locale.translate('strategy_summary_empty'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
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
                  color: colors.textPrimary,
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
}

class StrategySectionScreen extends StatefulWidget {
  final StrategySection section;

  const StrategySectionScreen({super.key, required this.section});

  @override
  State<StrategySectionScreen> createState() => _StrategySectionScreenState();
}

class _StrategySectionScreenState extends State<StrategySectionScreen> {
  final TextEditingController _whatIfController = TextEditingController();
  final TextEditingController _marketingController = TextEditingController();
  String _selectedAnalysisType = 'swot';

  static const List<String> _whatIfTemplateKeys = [
    'strategy_whatif_template_revenue_drop',
    'strategy_whatif_template_purchase_costs',
    'strategy_whatif_template_new_employee',
  ];

  static const List<String> _marketingTemplateKeys = [
    'strategy_marketing_template_concrete',
    'strategy_marketing_template_self_checkout',
    'strategy_marketing_template_wholesale_builders',
  ];

  bool _canManageStrategy(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.strategy);
  }

  @override
  void dispose() {
    _whatIfController.dispose();
    _marketingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canManage = _canManageStrategy(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _strategySectionTitle(locale, widget.section),
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      floatingActionButton: canManage
          ? _buildSectionFab(context, locale)
          : null,
      body: switch (widget.section) {
        StrategySection.whatIf => _buildWhatIfTab(context),
        StrategySection.marketing => _buildMarketingTab(context),
        StrategySection.matrices => _buildAnalysisTab(context),
        StrategySection.macro => _buildMacroTab(context),
        StrategySection.news => _buildNewsTab(context),
        StrategySection.scenarios => _buildScenariosTab(context),
        StrategySection.summary => _buildSummaryTab(context),
      },
    );
  }

  Widget? _buildSectionFab(BuildContext context, LanguageCubit locale) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (widget.section == StrategySection.macro) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showCreateMacroSheet(context),
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(TablerIcons.plus),
        label: Text(
          locale.translate('strategy_add_macro'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (widget.section == StrategySection.scenarios) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.read<StrategyBloc>().add(
          GenerateScenariosRequested(_currentQuarter()),
        ),
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(TablerIcons.sparkles),
        label: Text(
          locale.translate('strategy_scenarios_generate'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return null;
  }

  void _showCreateMacroSheet(BuildContext context) {
    final locale = context.read<LanguageCubit>();
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('strategy_add_macro'),
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('strategy_macro_name'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: valueCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: locale.translate('strategy_macro_value'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: unitCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('strategy_macro_unit'),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final value = parseLocalizedNumber(
                  context,
                  valueCtrl.text.trim(),
                );
                if (nameCtrl.text.trim().isEmpty || value == null) return;
                context.read<StrategyBloc>().add(
                  CreateMacroIndicatorRequested(
                    name: nameCtrl.text.trim(),
                    value: value,
                    unit: unitCtrl.text.trim().isEmpty
                        ? null
                        : unitCtrl.text.trim(),
                  ),
                );
                Navigator.pop(context);
              },
              child: Text(locale.translate('common_create')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIfTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isWhatIfLoading != current.isWhatIfLoading ||
          previous.whatIfAnswer != current.whatIfAnswer,
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              localeCubit.translate('strategy_whatif_description'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 12),

            // Список шаблонов
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _whatIfTemplateKeys.map((templateKey) {
                final template = localeCubit.translate(templateKey);
                return ActionChip(
                  label: Text(template, style: textStyles.smallSans),
                  backgroundColor: colors.surfaceNested,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onPressed: () {
                    _whatIfController.text = template;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Поле ввода вопроса
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _whatIfController,
                    decoration: InputDecoration(
                      hintText: localeCubit.translate('strategy_whatif_hint'),
                      fillColor: colors.surface,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      state.isWhatIfLoading || !_canManageStrategy(context)
                      ? null
                      : () {
                          final query = _whatIfController.text.trim();
                          if (query.isNotEmpty) {
                            context.read<StrategyBloc>().add(
                              AskWhatIfRequested(query),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: colors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: Icon(
                    TablerIcons.send,
                    semanticLabel: localeCubit.translate('common_send'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (state.isWhatIfLoading)
              const StrategyOverviewShimmer()
            else if (state.whatIfAnswer != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.accentAmber),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(TablerIcons.brain, color: colors.accentAmber),
                        const SizedBox(width: 8),
                        Text(
                          localeCubit.translate('strategy_scenario_analysis'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.accentAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localeCubit.translateMessage(state.whatIfAnswer!),
                      style: textStyles.bodySans.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMarketingTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isMarketingLoading != current.isMarketingLoading ||
          previous.marketingIdeas != current.marketingIdeas,
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              localeCubit.translate('strategy_marketing_description'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 12),

            // Список шаблонов
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _marketingTemplateKeys.map((templateKey) {
                final template = localeCubit.translate(templateKey);
                return ActionChip(
                  label: Text(template, style: textStyles.smallSans),
                  backgroundColor: colors.surfaceNested,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onPressed: () {
                    _marketingController.text = template;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Поле ввода запроса
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _marketingController,
                    decoration: InputDecoration(
                      hintText: localeCubit.translate(
                        'strategy_marketing_hint',
                      ),
                      fillColor: colors.surface,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      state.isMarketingLoading || !_canManageStrategy(context)
                      ? null
                      : () {
                          final query = _marketingController.text.trim();
                          if (query.isNotEmpty) {
                            context.read<StrategyBloc>().add(
                              GenerateMarketingIdeasRequested(query),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: colors.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  child: Icon(
                    TablerIcons.send,
                    semanticLabel: localeCubit.translate('common_send'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (state.isMarketingLoading)
              const StrategyOverviewShimmer()
            else if (state.marketingIdeas.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.brand),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(TablerIcons.bulb, color: colors.brand),
                        const SizedBox(width: 8),
                        Text(
                          localeCubit.translate('strategy_marketing_ideas'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...state.marketingIdeas.map(
                      (idea) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: textStyles.bodySans.copyWith(
                                color: colors.brand,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                localeCubit.translateMessage(idea),
                                style: textStyles.bodySans.copyWith(
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnalysisTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isAnalysisLoading != current.isAnalysisLoading ||
          previous.latestAnalysis != current.latestAnalysis,
      builder: (context, state) {
        final analysis = state.latestAnalysis;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(
              LoadStrategicAnalyses(_selectedAnalysisType, forceRefresh: true),
            );
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Выбор типа матрицы
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('SWOT'),
                      labelStyle: textStyles.captionSans.copyWith(
                        color: _selectedAnalysisType == 'swot'
                            ? Colors.white
                            : colors.textPrimary,
                        fontWeight: _selectedAnalysisType == 'swot'
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      checkmarkColor: Colors.white,
                      selected: _selectedAnalysisType == 'swot',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAnalysisType = 'swot';
                          });
                          context.read<StrategyBloc>().add(
                            const LoadStrategicAnalyses('swot'),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('PESTEL'),
                      labelStyle: textStyles.captionSans.copyWith(
                        color: _selectedAnalysisType == 'pestel'
                            ? Colors.white
                            : colors.textPrimary,
                        fontWeight: _selectedAnalysisType == 'pestel'
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      checkmarkColor: Colors.white,
                      selected: _selectedAnalysisType == 'pestel',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAnalysisType = 'pestel';
                          });
                          context.read<StrategyBloc>().add(
                            const LoadStrategicAnalyses('pestel'),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('BCG'),
                      labelStyle: textStyles.captionSans.copyWith(
                        color: _selectedAnalysisType == 'bcg'
                            ? Colors.white
                            : colors.textPrimary,
                        fontWeight: _selectedAnalysisType == 'bcg'
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      checkmarkColor: Colors.white,
                      selected: _selectedAnalysisType == 'bcg',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAnalysisType = 'bcg';
                          });
                          context.read<StrategyBloc>().add(
                            const LoadStrategicAnalyses('bcg'),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Кнопка AI генерации
              ElevatedButton.icon(
                onPressed:
                    state.isGeneratingAnalysis || !_canManageStrategy(context)
                    ? null
                    : () {
                        context.read<StrategyBloc>().add(
                          GenerateStrategicAnalysis(
                            type: _selectedAnalysisType,
                            period: _currentQuarter(),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(TablerIcons.plus),
                label: Text(
                  localeCubit.translate(
                    state.isGeneratingAnalysis
                        ? 'strategy_analyzing_company'
                        : 'strategy_generate_analysis',
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (state.isAnalysisLoading || state.isGeneratingAnalysis)
                const StrategyOverviewShimmer()
              else if (analysis == null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          TablerIcons.target_off,
                          color: colors.textSecondary,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localeCubit.translate('strategy_no_analysis'),
                          style: textStyles.captionSans,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localeCubit.translate(
                          'strategy_analysis_period',
                          params: {'period': analysis.period},
                        ),
                        style: textStyles.smallSans,
                      ),
                    ),
                    if (_canManageStrategy(context))
                      IconButton(
                        icon: Icon(
                          TablerIcons.trash,
                          size: 18,
                          color: colors.accentRed,
                        ),
                        onPressed: () {
                          context.read<StrategyBloc>().add(
                            DeleteAnalysisRequested(analysis.id),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (analysis.type == 'swot')
                  _buildSwotGrid(analysis.data)
                else if (analysis.type == 'pestel')
                  _buildPestelList(analysis.data)
                else if (analysis.type == 'bcg')
                  _buildBcgList(analysis.data),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwotGrid(Map<String, dynamic> data) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    Widget buildQuadrantCard(String title, dynamic itemsVal, Color color) {
      final List<dynamic> items = itemsVal is List ? itemsVal : [];
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 14.5,
              ),
            ),
            const Divider(),
            if (items.isEmpty)
              Text(
                localeCubit.translate('strategy_no_data'),
                style: textStyles.captionSans,
              )
            else
              ...items.map(
                (it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: textStyles.bodySans.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          localeCubit.translateMessage(it.toString()),
                          style: textStyles.captionSans.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        buildQuadrantCard(
          localeCubit.translate('strategy_swot_strengths'),
          data['strengths'],
          colors.accentGreen,
        ),
        const SizedBox(height: 12),
        buildQuadrantCard(
          localeCubit.translate('strategy_swot_weaknesses'),
          data['weaknesses'],
          colors.accentRed,
        ),
        const SizedBox(height: 12),
        buildQuadrantCard(
          localeCubit.translate('strategy_swot_opportunities'),
          data['opportunities'],
          colors.brand,
        ),
        const SizedBox(height: 12),
        buildQuadrantCard(
          localeCubit.translate('strategy_swot_threats'),
          data['threats'],
          colors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildPestelList(Map<String, dynamic> data) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    final factors = [
      {'key': 'political', 'labelKey': 'strategy_pestel_political'},
      {'key': 'economic', 'labelKey': 'strategy_pestel_economic'},
      {'key': 'social', 'labelKey': 'strategy_pestel_social'},
      {'key': 'technological', 'labelKey': 'strategy_pestel_technological'},
      {'key': 'environmental', 'labelKey': 'strategy_pestel_environmental'},
      {'key': 'legal', 'labelKey': 'strategy_pestel_legal'},
    ];

    return Column(
      children: factors.map((f) {
        final List<dynamic> items = (data[f['key']] is List)
            ? data[f['key']]
            : [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ExpansibleWidget(
            title: Text(
              localeCubit.translate(f['labelKey']!),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              localeCubit.translatePlural(
                'strategy_factors_found',
                items.length,
              ),
              style: textStyles.captionSans,
            ),
            children: [
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text(
                  localeCubit.translate('strategy_data_unavailable'),
                  style: textStyles.captionSans,
                )
              else
                ...items.map(
                  (it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: textStyles.bodySans.copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            localeCubit.translateMessage(it.toString()),
                            style: textStyles.bodySans,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBcgList(Map<String, dynamic> data) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final List<dynamic> items = data['items'] is List ? data['items'] : [];

    String translateQuadrant(String q) {
      switch (q) {
        case 'star':
          return localeCubit.translate('strategy_bcg_star');
        case 'cash_cow':
          return localeCubit.translate('strategy_bcg_cash_cow');
        case 'question':
          return localeCubit.translate('strategy_bcg_question');
        case 'dog':
          return localeCubit.translate('strategy_bcg_dog');
        default:
          return q;
      }
    }

    Color getQuadrantColor(String q) {
      switch (q) {
        case 'star':
          return colors.accentGreen;
        case 'cash_cow':
          return colors.brand;
        case 'question':
          return colors.accentAmber;
        default:
          return colors.textSecondary;
      }
    }

    return Column(
      children: [
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Center(
              child: Text(
                localeCubit.translate('strategy_bcg_no_categories'),
                style: textStyles.captionSans,
              ),
            ),
          )
        else
          ...items.map((it) {
            final map = it as Map<String, dynamic>;
            final name = map['name'] ?? '—';
            final share = (map['share'] ?? 0.0) as double;
            final growth = (map['growth'] ?? 0.0) as double;
            final quadrant = map['quadrant'] ?? 'question';
            final color = getQuadrantColor(quadrant);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            localeCubit.translate(
                              'strategy_bcg_market_metrics',
                              params: {
                                'share': (share * 100).toStringAsFixed(1),
                                'growth': (growth * 100).toStringAsFixed(1),
                              },
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        translateQuadrant(quadrant),
                        style: textStyles.smallSans.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMacroTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isMacroLoading != current.isMacroLoading ||
          previous.macroLoaded != current.macroLoaded ||
          previous.macro != current.macro,
      builder: (context, state) {
        if (state.isMacroLoading && !state.macroLoaded) {
          return const StrategyOverviewShimmer();
        }
        if (state.macro.isEmpty) {
          return Center(
            child: Text(
              locale.translate('strategy_macro_empty'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(
              const LoadMacroIndicators(forceRefresh: true),
            );
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.macro.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = state.macro[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatLocalizedDateTime(
                              context,
                              m.indicatorDate,
                              style: LocalizedDateTimeStyle.date,
                            ),
                            style: textStyles.smallMono.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${m.value}${m.unit != null ? ' ${m.unit}' : ''}',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: colors.brand,
                      ),
                    ),
                    if (_canManageStrategy(context))
                      IconButton(
                        icon: Icon(
                          TablerIcons.trash,
                          size: 18,
                          color: colors.accentRed,
                        ),
                        onPressed: () {
                          context.read<StrategyBloc>().add(
                            DeleteMacroIndicatorRequested(m.id),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNewsTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isNewsLoading != current.isNewsLoading ||
          previous.newsLoaded != current.newsLoaded ||
          previous.news != current.news,
      builder: (context, state) {
        if (state.isNewsLoading && !state.newsLoaded) {
          return const StrategyOverviewShimmer();
        }
        if (state.news.isEmpty) {
          return Center(
            child: Text(
              locale.translate('strategy_news_empty'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(
              const LoadNews(forceRefresh: true),
            );
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.news.length,
            itemBuilder: (context, index) {
              final source = state.news[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (source.items.isEmpty)
                      Text(
                        locale.translate('strategy_news_empty'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      )
                    else
                      ...source.items
                          .take(5)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(
                                  item.title,
                                  style: textStyles.captionSans.copyWith(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildScenariosTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isScenariosLoading != current.isScenariosLoading ||
          previous.scenariosLoaded != current.scenariosLoaded ||
          previous.scenarios != current.scenarios,
      builder: (context, state) {
        if (state.isScenariosLoading && !state.scenariosLoaded) {
          return const StrategyOverviewShimmer();
        }
        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(
              LoadScenarios(quarter: _currentQuarter(), forceRefresh: true),
            );
          },
          child: state.scenarios.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Text(
                        locale.translate('strategy_scenarios_empty'),
                        style: textStyles.bodySans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: state.scenarios.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = state.scenarios[index];
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
                          Text(
                            s.title,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.quarter,
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.content,
                            style: textStyles.captionSans.copyWith(
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          if (_canManageStrategy(context))
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: Icon(
                                  TablerIcons.trash,
                                  size: 18,
                                  color: colors.accentRed,
                                ),
                                onPressed: () {
                                  context.read<StrategyBloc>().add(
                                    DeleteScenarioRequested(s.id),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildSummaryTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      buildWhen: (previous, current) =>
          previous.isSummaryLoading != current.isSummaryLoading ||
          previous.summaryLoaded != current.summaryLoaded ||
          previous.dailySummary != current.dailySummary,
      builder: (context, state) {
        if (state.isSummaryLoading && !state.summaryLoaded) {
          return const StrategyOverviewShimmer();
        }
        final summary = state.dailySummary;
        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(
              const LoadDailySummary(forceRefresh: true),
            );
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (summary == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    locale.translate('strategy_summary_empty'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                )
              else ...[
                Text(
                  summary.date,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    summary.summary,
                    style: textStyles.bodySans.copyWith(
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
