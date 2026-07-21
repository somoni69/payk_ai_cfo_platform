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
