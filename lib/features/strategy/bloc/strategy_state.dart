import 'package:equatable/equatable.dart';
import '../domain/strategy_models.dart';

class StrategyState extends Equatable {
  final bool isWhatIfLoading;
  final String? whatIfAnswer;
  final bool isMarketingLoading;
  final List<String> marketingIdeas;
  final bool isAnalysisLoading;
  final List<StrategicAnalysis> analyses;
  final bool isGeneratingAnalysis;
  final StrategicAnalysis? latestAnalysis;

  final List<MacroIndicator> macro;
  final bool macroLoaded;
  final bool isMacroLoading;

  final List<StrategyScenario> scenarios;
  final bool scenariosLoaded;
  final bool isScenariosLoading;

  final DailySummary? dailySummary;
  final bool summaryLoaded;
  final bool isSummaryLoading;

  final List<NewsSource> news;
  final bool newsLoaded;
  final bool isNewsLoading;

  final String? errorMessage;

  const StrategyState({
    this.isWhatIfLoading = false,
    this.whatIfAnswer,
    this.isMarketingLoading = false,
    this.marketingIdeas = const [],
    this.isAnalysisLoading = false,
    this.analyses = const [],
    this.isGeneratingAnalysis = false,
    this.latestAnalysis,
    this.macro = const [],
    this.macroLoaded = false,
    this.isMacroLoading = false,
    this.scenarios = const [],
    this.scenariosLoaded = false,
    this.isScenariosLoading = false,
    this.dailySummary,
    this.summaryLoaded = false,
    this.isSummaryLoading = false,
    this.news = const [],
    this.newsLoaded = false,
    this.isNewsLoading = false,
    this.errorMessage,
  });

  StrategyState copyWith({
    bool? isWhatIfLoading,
    String? whatIfAnswer,
    bool? isMarketingLoading,
    List<String>? marketingIdeas,
    bool? isAnalysisLoading,
    List<StrategicAnalysis>? analyses,
    bool? isGeneratingAnalysis,
    StrategicAnalysis? latestAnalysis,
    List<MacroIndicator>? macro,
    bool? macroLoaded,
    bool? isMacroLoading,
    List<StrategyScenario>? scenarios,
    bool? scenariosLoaded,
    bool? isScenariosLoading,
    DailySummary? dailySummary,
    bool? summaryLoaded,
    bool? isSummaryLoading,
    List<NewsSource>? news,
    bool? newsLoaded,
    bool? isNewsLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StrategyState(
      isWhatIfLoading: isWhatIfLoading ?? this.isWhatIfLoading,
      whatIfAnswer: whatIfAnswer ?? this.whatIfAnswer,
      isMarketingLoading: isMarketingLoading ?? this.isMarketingLoading,
      marketingIdeas: marketingIdeas ?? this.marketingIdeas,
      isAnalysisLoading: isAnalysisLoading ?? this.isAnalysisLoading,
      analyses: analyses ?? this.analyses,
      isGeneratingAnalysis: isGeneratingAnalysis ?? this.isGeneratingAnalysis,
      latestAnalysis: latestAnalysis ?? this.latestAnalysis,
      macro: macro ?? this.macro,
      macroLoaded: macroLoaded ?? this.macroLoaded,
      isMacroLoading: isMacroLoading ?? this.isMacroLoading,
      scenarios: scenarios ?? this.scenarios,
      scenariosLoaded: scenariosLoaded ?? this.scenariosLoaded,
      isScenariosLoading: isScenariosLoading ?? this.isScenariosLoading,
      dailySummary: dailySummary ?? this.dailySummary,
      summaryLoaded: summaryLoaded ?? this.summaryLoaded,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      news: news ?? this.news,
      newsLoaded: newsLoaded ?? this.newsLoaded,
      isNewsLoading: isNewsLoading ?? this.isNewsLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    isWhatIfLoading,
    whatIfAnswer,
    isMarketingLoading,
    marketingIdeas,
    isAnalysisLoading,
    analyses,
    isGeneratingAnalysis,
    latestAnalysis,
    macro,
    macroLoaded,
    isMacroLoading,
    scenarios,
    scenariosLoaded,
    isScenariosLoading,
    dailySummary,
    summaryLoaded,
    isSummaryLoading,
    news,
    newsLoaded,
    isNewsLoading,
    errorMessage,
  ];
}
