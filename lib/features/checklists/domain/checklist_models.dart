import 'package:equatable/equatable.dart';

class ChecklistEntry extends Equatable {
  final String id;
  final String runId;
  final String text;
  final bool isDone;
  final DateTime? createdAt;

  const ChecklistEntry({
    required this.id,
    required this.runId,
    required this.text,
    this.isDone = false,
    this.createdAt,
  });

  ChecklistEntry copyWith({bool? isDone, String? text}) {
    return ChecklistEntry(
      id: id,
      runId: runId,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }

  factory ChecklistEntry.fromJson(Map<String, dynamic> json) {
    return ChecklistEntry(
      id: json['id'] as String? ?? '',
      runId: json['run_id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'run_id': runId,
      'text': text,
      'is_done': isDone,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, runId, text, isDone, createdAt];
}

class ChecklistRun extends Equatable {
  final String id;
  final String title;
  final String branchName;
  final String responsiblePerson;
  final List<ChecklistEntry> entries;

  const ChecklistRun({
    required this.id,
    required this.title,
    required this.branchName,
    required this.responsiblePerson,
    required this.entries,
  });

  int get doneCount => entries.where((e) => e.isDone).length;
  int get totalCount => entries.length;
  double get progressPercentage =>
      totalCount > 0 ? (doneCount / totalCount) : 0.0;

  factory ChecklistRun.fromJson(Map<String, dynamic> json) {
    return ChecklistRun(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      branchName: json['branch_name'] as String? ?? '',
      responsiblePerson: json['responsible_person'] as String? ?? '',
      entries: (json['entries'] as List? ?? [])
          .map((e) => ChecklistEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'branch_name': branchName,
      'responsible_person': responsiblePerson,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    branchName,
    responsiblePerson,
    entries,
  ];
}
