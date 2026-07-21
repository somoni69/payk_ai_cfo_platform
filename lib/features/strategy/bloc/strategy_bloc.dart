import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/strategy_models.dart';
import '../domain/strategy_repository.dart';
import 'strategy_event.dart';
import 'strategy_state.dart';

class StrategyBloc extends Bloc<StrategyEvent, StrategyState> {
  StrategyBloc(this._repository) : super(const StrategyState()) {
    on<AskWhatIfRequested>(_onAskWhatIfRequested);
    on<GenerateMarketingIdeasRequested>(_onGenerateMarketingIdeasRequested);
    on<LoadStrategicAnalyses>(_onLoadStrategicAnalyses);
    on<GenerateStrategicAnalysis>(_onGenerateStrategicAnalysis);
  }

  final StrategyRepository _repository;
  final Map<String, Future<List<StrategicAnalysis>>> _analysisRequests = {};
  int _analysisGeneration = 0;

  Future<void> _onAskWhatIfRequested(
    AskWhatIfRequested event,
    Emitter<StrategyState> emit,
  ) async {
    emit(state.copyWith(isWhatIfLoading: true, clearError: true));
    try {
      final result = await _repository.askWhatIf(event.question);
      if (emit.isDone) return;
      emit(state.copyWith(isWhatIfLoading: false, whatIfAnswer: result.answer));
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isWhatIfLoading: false,
          errorMessage:
              'Не удалось выполнить AI-сценарий. Проверьте соединение.',
        ),
      );
    }
  }

  Future<void> _onGenerateMarketingIdeasRequested(
    GenerateMarketingIdeasRequested event,
    Emitter<StrategyState> emit,
  ) async {
    emit(state.copyWith(isMarketingLoading: true, clearError: true));
    try {
      final result = await _repository.generateAiIdeas(event.prompt);
      if (emit.isDone) return;
      emit(
        state.copyWith(isMarketingLoading: false, marketingIdeas: result.ideas),
      );
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isMarketingLoading: false,
          errorMessage: 'Не удалось получить AI-идеи. Проверьте соединение.',
        ),
      );
    }
  }

  Future<void> _onLoadStrategicAnalyses(
    LoadStrategicAnalyses event,
    Emitter<StrategyState> emit,
  ) async {
    final generation = ++_analysisGeneration;
    emit(state.copyWith(isAnalysisLoading: true, clearError: true));

    var request = _analysisRequests[event.type];
    if (request == null) {
      request = _repository.getAnalyses(
        event.type,
        forceRefresh: event.forceRefresh,
      );
      _analysisRequests[event.type] = request;
    }

    try {
      final result = await request;
      if (generation != _analysisGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          isAnalysisLoading: false,
          analyses: result,
          latestAnalysis: result.firstOrNull,
        ),
      );
    } catch (_) {
      if (generation != _analysisGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          isAnalysisLoading: false,
          errorMessage:
              'Не удалось загрузить стратегический анализ. Повторите попытку.',
        ),
      );
    } finally {
      if (identical(_analysisRequests[event.type], request)) {
        _analysisRequests.remove(event.type);
      }
      if (event.completion?.isCompleted == false) {
        event.completion!.complete();
      }
    }
  }

  Future<void> _onGenerateStrategicAnalysis(
    GenerateStrategicAnalysis event,
    Emitter<StrategyState> emit,
  ) async {
    emit(state.copyWith(isGeneratingAnalysis: true, clearError: true));
    try {
      final result = await _repository.generateAnalysis(
        event.type,
        event.period,
      );
      if (emit.isDone) return;
      final updatedList = List<StrategicAnalysis>.from(state.analyses)
        ..removeWhere((analysis) => analysis.id == result.id)
        ..insert(0, result);

      emit(
        state.copyWith(
          isGeneratingAnalysis: false,
          analyses: updatedList,
          latestAnalysis: result,
        ),
      );
    } catch (error) {
      if (_isCancelled(error) || emit.isDone) return;
      emit(
        state.copyWith(
          isGeneratingAnalysis: false,
          errorMessage:
              'Не удалось сгенерировать анализ. Проверьте соединение.',
        ),
      );
    }
  }

  bool _isCancelled(Object error) =>
      error is DioException && CancelToken.isCancel(error);

  @override
  Future<void> close() {
    final repository = _repository;
    if (repository is CancellableStrategyRepository) {
      (repository as CancellableStrategyRepository).cancelPendingRequests();
    }
    return super.close();
  }
}
