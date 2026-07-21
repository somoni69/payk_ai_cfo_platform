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
    errorMessage,
  ];
}
