import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/user_facing_error.dart';
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
    on<LoadMacroIndicators>(_onLoadMacro);
    on<LoadScenarios>(_onLoadScenarios);
    on<GenerateScenariosRequested>(_onGenerateScenarios);
    on<LoadDailySummary>(_onLoadSummary);
    on<LoadNews>(_onLoadNews);
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

  Future<void> _onLoadMacro(
    LoadMacroIndicators event,
    Emitter<StrategyState> emit,
  ) async {
    if (state.macroLoaded && !event.forceRefresh) return;
    emit(state.copyWith(isMacroLoading: true, clearError: true));
    try {
      final rows = await _repository.getMacroIndicators();
      emit(
        state.copyWith(
          macro: rows,
          macroLoaded: true,
          isMacroLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isMacroLoading: false,
          errorMessage: ErrorKeys.loadFailed,
        ),
      );
    }
  }

  Future<void> _onLoadScenarios(
    LoadScenarios event,
    Emitter<StrategyState> emit,
  ) async {
    if (state.scenariosLoaded && !event.forceRefresh) return;
    emit(state.copyWith(isScenariosLoading: true, clearError: true));
    try {
      final rows = await _repository.getScenarios(quarter: event.quarter);
      emit(
        state.copyWith(
          scenarios: rows,
          scenariosLoaded: true,
          isScenariosLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isScenariosLoading: false,
          errorMessage: ErrorKeys.loadFailed,
        ),
      );
    }
  }

  Future<void> _onGenerateScenarios(
    GenerateScenariosRequested event,
    Emitter<StrategyState> emit,
  ) async {
    emit(state.copyWith(isScenariosLoading: true, clearError: true));
    try {
      final rows = await _repository.generateScenarios(event.quarter);
      emit(
        state.copyWith(
          scenarios: rows,
          scenariosLoaded: true,
          isScenariosLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isScenariosLoading: false,
          errorMessage: ErrorKeys.loadFailed,
        ),
      );
    }
  }

  Future<void> _onLoadSummary(
    LoadDailySummary event,
    Emitter<StrategyState> emit,
  ) async {
    if (state.summaryLoaded && !event.forceRefresh) return;
    emit(state.copyWith(isSummaryLoading: true, clearError: true));
    try {
      final summary = await _repository.getDailySummary();
      emit(
        state.copyWith(
          dailySummary: summary,
          summaryLoaded: true,
          isSummaryLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isSummaryLoading: false,
          errorMessage: ErrorKeys.loadFailed,
        ),
      );
    }
  }

  Future<void> _onLoadNews(
    LoadNews event,
    Emitter<StrategyState> emit,
  ) async {
    if (state.newsLoaded && !event.forceRefresh) return;
    emit(state.copyWith(isNewsLoading: true, clearError: true));
    try {
      final news = await _repository.getNews();
      emit(
        state.copyWith(
          news: news,
          newsLoaded: true,
          isNewsLoading: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isNewsLoading: false,
          errorMessage: ErrorKeys.loadFailed,
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
