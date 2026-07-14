import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/localization/language_cubit.dart';
import '../../features/strategy/bloc/strategy_bloc.dart';
import '../../features/strategy/bloc/strategy_event.dart';
import '../../features/strategy/bloc/strategy_state.dart';
import '../../features/strategy/domain/strategy_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/expansible_widget.dart';

class StrategyScreen extends StatelessWidget {
  const StrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
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

class _StrategyViewState extends State<StrategyView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _whatIfController = TextEditingController();
  final TextEditingController _marketingController = TextEditingController();

  final List<String> _whatIfTemplates = [
    'Что будет, если выручка снизится на 15%?',
    'Что будет, если расходы на закупки увеличатся на 10%?',
    'Что будет при найме нового сотрудника с окладом 3000 TJS?',
  ];

  final List<String> _marketingTemplates = [
    'Идеи продвижения производства бетона в Худжанде',
    'Креативные слоганы для кассы самообслуживания',
    'Каналы привлечения оптовых строителей в Душанбе',
  ];

  String _selectedAnalysisType = 'swot';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _whatIfController.dispose();
    _marketingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          localeCubit.translate('strat_title'),
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.brand,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: localeCubit.translate('strat_tab_whatif')),
            Tab(text: localeCubit.translate('strat_tab_marketing')),
            const Tab(text: 'Матрицы'),
          ],
        ),
      ),
      body: BlocListener<StrategyBloc, StrategyState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: colors.accentRed,
              ),
            );
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWhatIfTab(context),
            _buildMarketingTab(context),
            _buildAnalysisTab(context),
          ],
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
              localeCubit.translate('strat_whatif_desc'),
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),

            // Список шаблонов
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _whatIfTemplates.map((template) {
                return ActionChip(
                  label: Text(template, style: textStyles.smallSans),
                  backgroundColor: colors.surfaceNested,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      hintText: localeCubit.translate('strat_whatif_hint'),
                      fillColor: colors.surface,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: state.isWhatIfLoading
                      ? null
                      : () {
                          final query = _whatIfController.text.trim();
                          if (query.isNotEmpty) {
                            context.read<StrategyBloc>().add(AskWhatIfRequested(query));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentAmber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Icon(TablerIcons.send),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (state.isWhatIfLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
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
                          'AI АНАЛИЗ СЦЕНАРИЯ',
                          style: textStyles.captionSans.copyWith(
                            color: colors.accentAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.whatIfAnswer!,
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
              localeCubit.translate('strat_marketing_desc'),
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),

            // Список шаблонов
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _marketingTemplates.map((template) {
                return ActionChip(
                  label: Text(template, style: textStyles.smallSans),
                  backgroundColor: colors.surfaceNested,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      hintText: localeCubit.translate('strat_marketing_hint'),
                      fillColor: colors.surface,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: state.isMarketingLoading
                      ? null
                      : () {
                          final prompt = _marketingController.text.trim();
                          if (prompt.isNotEmpty) {
                            context.read<StrategyBloc>().add(GenerateMarketingIdeasRequested(prompt));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Icon(TablerIcons.bulb),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (state.isMarketingLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
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
                          'ИИ ИДЕИ ПРОДВИЖЕНИЯ',
                          style: textStyles.captionSans.copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.marketingIdeas.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                state.marketingIdeas[index],
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

    return BlocBuilder<StrategyBloc, StrategyState>(
      builder: (context, state) {
        final analysis = state.latestAnalysis;

        return RefreshIndicator(
          onRefresh: () async {
            context.read<StrategyBloc>().add(LoadStrategicAnalyses(_selectedAnalysisType));
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
                      selected: _selectedAnalysisType == 'swot',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAnalysisType = 'swot';
                          });
                          context.read<StrategyBloc>().add(const LoadStrategicAnalyses('swot'));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('PESTEL'),
                      selected: _selectedAnalysisType == 'pestel',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAnalysisType = 'pestel';
                          });
                          context.read<StrategyBloc>().add(const LoadStrategicAnalyses('pestel'));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('BCG'),
                      selected: _selectedAnalysisType == 'bcg',
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedAnalysisType = 'bcg';
                          });
                          context.read<StrategyBloc>().add(const LoadStrategicAnalyses('bcg'));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Кнопка AI генерации
              ElevatedButton.icon(
                onPressed: state.isGeneratingAnalysis
                    ? null
                    : () {
                        context.read<StrategyBloc>().add(GenerateStrategicAnalysis(
                              type: _selectedAnalysisType,
                              period: '2026-Q2',
                            ));
                      },
                icon: const Icon(TablerIcons.sparkles),
                label: Text(state.isGeneratingAnalysis ? 'ИИ анализирует компанию...' : 'Сгенерировать AI-анализ РТ'),
              ),
              const SizedBox(height: 20),

              if (state.isAnalysisLoading || state.isGeneratingAnalysis)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (analysis == null)
                LedgerCard(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(TablerIcons.target_off, color: colors.textSecondary, size: 36),
                        const SizedBox(height: 8),
                        Text('Нет сгенерированного анализа для этой матрицы', style: textStyles.captionSans),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'AI АНАЛИЗ ЗА ПЕРИОД: ${analysis.period}',
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
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const Divider(),
            if (items.isEmpty)
              Text('Нет данных', style: textStyles.captionSans)
            else
              ...items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(it.toString(), style: textStyles.bodySans.copyWith(fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      );
    }

    return Column(
      children: [
        buildQuadrantCard('Сильные стороны (Strengths)', data['strengths'], colors.accentGreen),
        const SizedBox(height: 12),
        buildQuadrantCard('Слабые стороны (Weaknesses)', data['weaknesses'], colors.accentRed),
        const SizedBox(height: 12),
        buildQuadrantCard('Возможности (Opportunities)', data['opportunities'], colors.brand),
        const SizedBox(height: 12),
        buildQuadrantCard('Угрозы (Threats)', data['threats'], colors.textSecondary),
      ],
    );
  }

  Widget _buildPestelList(Map<String, dynamic> data) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final factors = [
      {'key': 'political', 'label': 'Политические факторы'},
      {'key': 'economic', 'label': 'Экономические факторы'},
      {'key': 'social', 'label': 'Социальные факторы'},
      {'key': 'technological', 'label': 'Технологические факторы'},
      {'key': 'environmental', 'label': 'Экологические факторы'},
      {'key': 'legal', 'label': 'Правовые факторы'},
    ];

    return Column(
      children: factors.map((f) {
        final List<dynamic> items = (data[f['key']] is List) ? data[f['key']] : [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ExpansibleWidget(
            title: Text(
              f['label']!,
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${items.length} факторов найдено', style: textStyles.captionSans),
            children: [
              const SizedBox(height: 8),
              if (items.isEmpty)
                Text('Данные отсутствуют', style: textStyles.captionSans)
              else
                ...items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: colors.brand, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(it.toString(), style: textStyles.bodySans),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBcgList(Map<String, dynamic> data) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final List<dynamic> items = data['items'] is List ? data['items'] : [];

    String translateQuadrant(String q) {
      switch (q) {
        case 'star':
          return 'Звезда';
        case 'cash_cow':
          return 'Дойная корова';
        case 'question':
          return 'Трудные дети';
        case 'dog':
          return 'Собака';
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
            child: Center(child: Text('Нет товарных категорий в BCG анализе', style: textStyles.captionSans)),
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
                          Text(name, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Доля рынка: ${(share * 100).toStringAsFixed(1)}% • Рост рынка: ${(growth * 100).toStringAsFixed(1)}%',
                            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        translateQuadrant(quadrant),
                        style: textStyles.smallSans.copyWith(color: color, fontWeight: FontWeight.bold),
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
}
