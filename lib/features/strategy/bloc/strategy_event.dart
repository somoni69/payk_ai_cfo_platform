import 'dart:async';

import 'package:equatable/equatable.dart';

abstract class StrategyEvent extends Equatable {
  const StrategyEvent();

  @override
  List<Object?> get props => [];
}

/// Запрос на What-if симуляцию
class AskWhatIfRequested extends StrategyEvent {
  final String question;

  const AskWhatIfRequested(this.question);

  @override
  List<Object?> get props => [question];
}

/// Запрос на генерацию маркетинговых идей
class GenerateMarketingIdeasRequested extends StrategyEvent {
  final String prompt;

  const GenerateMarketingIdeasRequested(this.prompt);

  @override
  List<Object?> get props => [prompt];
}

class LoadStrategicAnalyses extends StrategyEvent {
  final String type; // 'swot', 'bcg', 'pestel'
  final bool forceRefresh;
  final Completer<void>? completion;

  const LoadStrategicAnalyses(
    this.type, {
    this.forceRefresh = false,
    this.completion,
  });

  @override
  List<Object?> get props => [type, forceRefresh];
}

class GenerateStrategicAnalysis extends StrategyEvent {
  final String type;
  final String period;

  const GenerateStrategicAnalysis({required this.type, required this.period});

  @override
  List<Object?> get props => [type, period];
}

class LoadMacroIndicators extends StrategyEvent {
  final bool forceRefresh;
  const LoadMacroIndicators({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class LoadScenarios extends StrategyEvent {
  final String? quarter;
  final bool forceRefresh;
  const LoadScenarios({this.quarter, this.forceRefresh = false});

  @override
  List<Object?> get props => [quarter, forceRefresh];
}

class GenerateScenariosRequested extends StrategyEvent {
  final String quarter;
  const GenerateScenariosRequested(this.quarter);

  @override
  List<Object?> get props => [quarter];
}

class DeleteAnalysisRequested extends StrategyEvent {
  final String id;
  const DeleteAnalysisRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class DeleteScenarioRequested extends StrategyEvent {
  final String id;
  const DeleteScenarioRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateMacroIndicatorRequested extends StrategyEvent {
  final String name;
  final double value;
  final String? unit;

  const CreateMacroIndicatorRequested({
    required this.name,
    required this.value,
    this.unit,
  });

  @override
  List<Object?> get props => [name, value, unit];
}

class DeleteMacroIndicatorRequested extends StrategyEvent {
  final String id;
  const DeleteMacroIndicatorRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadDailySummary extends StrategyEvent {
  final bool forceRefresh;
  const LoadDailySummary({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class LoadNews extends StrategyEvent {
  final bool forceRefresh;
  const LoadNews({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}
