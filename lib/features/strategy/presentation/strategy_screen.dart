import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/strategy/bloc/strategy_bloc.dart';
import '../../../features/strategy/bloc/strategy_event.dart';
import '../../../features/strategy/bloc/strategy_state.dart';
import '../../../features/strategy/domain/strategy_repository.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

class StrategyScreen extends StatelessWidget {
  const StrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<StrategyBloc>(
      create: (context) => StrategyBloc(context.read<StrategyRepository>()),
      child: const StrategyView(),
    );
  }
}

class StrategyView extends StatefulWidget {
  const StrategyView({super.key});

  @override
  State<StrategyView> createState() => _StrategyViewState();
}

class _StrategyViewState extends State<StrategyView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _whatIfController = TextEditingController();
  final TextEditingController _marketingController = TextEditingController();

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

  String _selectedAnalysisType = 'swot';
  bool _analysisRequested = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  bool _canManageStrategy(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.strategy);
  }

  String get _currentQuarter {
    final now = DateTime.now();
    final year = now.year;
    final quarter = ((now.month - 1) ~/ 3) + 1;
    return '$year-Q$quarter';
  }

  void _handleTabChange() {
    if (!mounted || _tabController.indexIsChanging) return;
    // Rebuild tab-aware FAB (design_language).
    setState(() {});
    final bloc = context.read<StrategyBloc>();
    switch (_tabController.index) {
      case 2:
        if (!_analysisRequested) {
          _analysisRequested = true;
          bloc.add(LoadStrategicAnalyses(_selectedAnalysisType));
        }
        break;
      case 3:
        bloc.add(const LoadMacroIndicators());
        break;
      case 4:
        bloc.add(const LoadNews());
        break;
      case 5:
        bloc.add(LoadScenarios(quarter: _currentQuarter));
        break;
      case 6:
        bloc.add(const LoadDailySummary());
        break;
    }
  }

  Widget? _buildStrategyFab(BuildContext context) {
    // Scenarios tab only — generate AI scenarios.
    if (_tabController.index != 5 || !_canManageStrategy(context)) return null;
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    return FloatingActionButton.extended(
      onPressed: () => context.read<StrategyBloc>().add(
        GenerateScenariosRequested(_currentQuarter),
      ),
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
        locale.translate('strategy_scenarios_generate'),
        style: textStyles.bodySans.copyWith(
          color: colors.surface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _refreshAnalyses(BuildContext context) {
    final completion = Completer<void>();
    context.read<StrategyBloc>().add(
      LoadStrategicAnalyses(
        _selectedAnalysisType,
        forceRefresh: true,
        completion: completion,
      ),
    );
    return completion.future;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _whatIfController.dispose();
    _marketingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final localeCubit = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: _buildStrategyFab(context),
      body: BlocListener<StrategyBloc, StrategyState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localeCubit.translateMessage(state.errorMessage!),
                ),
                backgroundColor: colors.accentRed,
              ),
            );
          }
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              LedgerCollapsingHeader(
                title: localeCubit.translate('strategy_title'),
                pinned: true,
                floating: false,
                snap: false,
                bottom: LedgerTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    Tab(text: localeCubit.translate('strategy_tab_whatif')),
                    Tab(text: localeCubit.translate('strategy_tab_marketing')),
                    Tab(text: localeCubit.translate('strategy_tab_matrices')),
                    Tab(text: localeCubit.translate('strategy_tab_macro')),
                    Tab(text: localeCubit.translate('strategy_tab_news')),
                    Tab(text: localeCubit.translate('strategy_tab_scenarios')),
                    Tab(text: localeCubit.translate('strategy_tab_summary')),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildWhatIfTab(context),
              _buildMarketingTab(context),
              _buildAnalysisTab(context),
              _buildMacroTab(context),
              _buildNewsTab(context),
              _buildScenariosTab(context),
              _buildSummaryTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatIfTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              localeCubit.translate('strategy_whatif_description'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
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
              LedgerCard(
                borderColor: colors.accentAmber,
                backgroundColor: colors.accentAmber.withValues(alpha: 0.04),
                padding: const EdgeInsets.all(16),
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
                            fontWeight: FontWeight.w500,
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
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              localeCubit.translate('strategy_marketing_description'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
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

            // Поле ввода вопроса
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
                          final prompt = _marketingController.text.trim();
                          if (prompt.isNotEmpty) {
                            context.read<StrategyBloc>().add(
                              GenerateMarketingIdeasRequested(prompt),
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
                    TablerIcons.bulb,
                    semanticLabel: localeCubit.translate(
                      'strategy_generate_ideas_action',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (state.isMarketingLoading)
              const StrategyOverviewShimmer()
            else if (state.marketingIdeas.isNotEmpty)
              LedgerCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(TablerIcons.target, color: colors.brand),
                        const SizedBox(width: 8),
                        Text(
                          localeCubit.translate('strategy_marketing_ideas'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.marketingIdeas.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                localeCubit.translateMessage(
                                  state.marketingIdeas[index],
                                ),
                                style: textStyles.bodySans,
                              ),
                            ),
                          ],
                        );
                      },
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
      builder: (context, state) {
        final analysis = state.latestAnalysis;

        return RefreshIndicator(
          onRefresh: () => _refreshAnalyses(context),
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
                            ? FontWeight.w500
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
                            ? FontWeight.w500
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
                            ? FontWeight.w500
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
                            period: _currentQuarter,
                          ),
                        );
                      },
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
                LedgerCard(
                  padding: const EdgeInsets.all(24),
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
                Text(
                  localeCubit.translate(
                    'strategy_analysis_period',
                    params: {'period': analysis.period},
                  ),
                  style: textStyles.smallSans,
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
      return LedgerCard(
        borderColor: color.withValues(alpha: 0.5),
        backgroundColor: color.withValues(alpha: 0.03),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          localeCubit.translateMessage(it.toString()),
                          style: textStyles.captionSans,
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
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
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
                            fontWeight: FontWeight.w500,
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
          LedgerCard(
            padding: const EdgeInsets.all(16),
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
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
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
                              fontWeight: FontWeight.w500,
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
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        translateQuadrant(quadrant),
                        style: textStyles.smallSans.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
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
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = state.macro[index];
              return LedgerCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                        fontWeight: FontWeight.w500,
                        color: colors.brand,
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

  Widget _buildNewsTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return BlocBuilder<StrategyBloc, StrategyState>(
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
                        fontWeight: FontWeight.w500,
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
                              child: LedgerCard(
                                child: Text(
                                  item.title,
                                  style: textStyles.captionSans,
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
      builder: (context, state) {
        if (state.isScenariosLoading && !state.scenariosLoaded) {
          return const StrategyOverviewShimmer();
        }
        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(
              LoadScenarios(quarter: _currentQuarter, forceRefresh: true),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = state.scenarios[index];
                    return LedgerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.quarter,
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(s.content, style: textStyles.captionSans),
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
                LedgerCard(
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
                  ),
                ),
                const SizedBox(height: 8),
                LedgerCard(
                  child: Text(summary.summary, style: textStyles.bodySans),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
