import 'package:equatable/equatable.dart';
import '../domain/checklist_models.dart';

abstract class ChecklistsState extends Equatable {
  const ChecklistsState();

  @override
  List<Object?> get props => [];
}

class ChecklistsInitial extends ChecklistsState {}

class ChecklistsLoading extends ChecklistsState {}

class ChecklistsLoaded extends ChecklistsState {
  final List<ChecklistRun> todayRuns;
  final List<ChecklistTemplate> templates;
  final List<ChecklistSummaryRow> summary;
  final String? actionMessage;

  const ChecklistsLoaded({
    required this.todayRuns,
    this.templates = const [],
    this.summary = const [],
    this.actionMessage,
  });

  ChecklistsLoaded copyWith({
    List<ChecklistRun>? todayRuns,
    List<ChecklistTemplate>? templates,
    List<ChecklistSummaryRow>? summary,
    String? actionMessage,
    bool clearAction = false,
  }) {
    return ChecklistsLoaded(
      todayRuns: todayRuns ?? this.todayRuns,
      templates: templates ?? this.templates,
      summary: summary ?? this.summary,
      actionMessage: clearAction ? null : (actionMessage ?? this.actionMessage),
    );
  }

  @override
  List<Object?> get props => [todayRuns, templates, summary, actionMessage];
}

class ChecklistsError extends ChecklistsState {
  final String message;
  const ChecklistsError(this.message);

  @override
  List<Object?> get props => [message];
}
