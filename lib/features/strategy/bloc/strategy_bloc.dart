import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/strategy_models.dart';
import '../domain/strategy_repository.dart';
import 'strategy_event.dart';
import 'strategy_state.dart';

class StrategyBloc extends Bloc<StrategyEvent, StrategyState> {
  final StrategyRepository _repository;

  StrategyBloc(this._repository) : super(const StrategyState()) {
    on<AskWhatIfRequested>(_onAskWhatIfRequested);
    on<GenerateMarketingIdeasRequested>(_onGenerateMarketingIdeasRequested);
    on<LoadStrategicAnalyses>(_onLoadStrategicAnalyses);
    on<GenerateStrategicAnalysis>(_onGenerateStrategicAnalysis);
  }

  void _onAskWhatIfRequested(AskWhatIfRequested event, Emitter<StrategyState> emit) async {
    emit(state.copyWith(isWhatIfLoading: true, clearError: true));
    try {
      final res = await _repository.askWhatIf(event.question);
      emit(state.copyWith(
        isWhatIfLoading: false,
        whatIfAnswer: res.answer,
      ));
    } catch (e) {
      emit(state.copyWith(
        isWhatIfLoading: false,
        errorMessage: 'Ошибка AI: ${e.toString()}',
      ));
    }
  }

  void _onGenerateMarketingIdeasRequested(GenerateMarketingIdeasRequested event, Emitter<StrategyState> emit) async {
    emit(state.copyWith(isMarketingLoading: true, clearError: true));
    try {
      final res = await _repository.generateAiIdeas(event.prompt);
      emit(state.copyWith(
        isMarketingLoading: false,
        marketingIdeas: res.ideas,
      ));
    } catch (e) {
      emit(state.copyWith(
        isMarketingLoading: false,
        errorMessage: 'Ошибка AI: ${e.toString()}',
      ));
    }
  }

  void _onLoadStrategicAnalyses(LoadStrategicAnalyses event, Emitter<StrategyState> emit) async {
    emit(state.copyWith(isAnalysisLoading: true, clearError: true));
    try {
      final res = await _repository.getAnalyses(event.type);
      emit(state.copyWith(
        isAnalysisLoading: false,
        analyses: res,
        latestAnalysis: res.firstOrNull,
      ));
    } catch (e) {
      emit(state.copyWith(
        isAnalysisLoading: false,
        errorMessage: 'Ошибка загрузки анализа: ${e.toString()}',
      ));
    }
  }

  void _onGenerateStrategicAnalysis(GenerateStrategicAnalysis event, Emitter<StrategyState> emit) async {
    emit(state.copyWith(isGeneratingAnalysis: true, clearError: true));
    try {
      final res = await _repository.generateAnalysis(event.type, event.period);
      final updatedList = List<StrategicAnalysis>.from(state.analyses)
        ..insert(0, res);

      emit(state.copyWith(
        isGeneratingAnalysis: false,
        analyses: updatedList,
        latestAnalysis: res,
      ));
    } catch (e) {
      emit(state.copyWith(
        isGeneratingAnalysis: false,
        errorMessage: 'Ошибка AI генерации: ${e.toString()}',
      ));
    }
  }
}
