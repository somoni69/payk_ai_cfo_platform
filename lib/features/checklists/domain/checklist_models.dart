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

  factory ChecklistEntry.fromJson(Map<String, dynamic> json, {String? runId}) {
    return ChecklistEntry(
      id: (json['id'] ?? '').toString(),
      runId: (json['run_id'] ?? runId ?? '').toString(),
      text: json['text']?.toString() ?? '',
      isDone: json['is_done'] == true,
      createdAt: json['done_at'] != null
          ? DateTime.tryParse(json['done_at'].toString())
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString())
                : null),
    );
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
  final String? regulationText;
  final String? regulationName;

  const ChecklistRun({
    required this.id,
    required this.title,
    required this.branchName,
    required this.responsiblePerson,
    required this.entries,
    this.regulationText,
    this.regulationName,
  });

  int get doneCount => entries.where((e) => e.isDone).length;
  int get totalCount => entries.length;
  double get progressPercentage =>
      totalCount > 0 ? (doneCount / totalCount) : 0.0;

  factory ChecklistRun.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final entriesRaw = json['entries'] as List? ?? [];
    return ChecklistRun(
      id: id,
      title: (json['checklist_name'] ?? json['title'] ?? '').toString(),
      branchName: (json['branch_name'] ?? '').toString(),
      responsiblePerson: (json['responsible_person'] ?? '').toString(),
      regulationText: json['regulation_text']?.toString(),
      regulationName: json['regulation_name']?.toString(),
      entries: entriesRaw
          .whereType<Map>()
          .map(
            (e) => ChecklistEntry.fromJson(
              Map<String, dynamic>.from(e),
              runId: id,
            ),
          )
          .toList(),
    );
  }

  ChecklistRun copyWith({List<ChecklistEntry>? entries}) {
    return ChecklistRun(
      id: id,
      title: title,
      branchName: branchName,
      responsiblePerson: responsiblePerson,
      entries: entries ?? this.entries,
      regulationText: regulationText,
      regulationName: regulationName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    branchName,
    responsiblePerson,
    entries,
    regulationText,
    regulationName,
  ];
}

class ChecklistTemplateItem extends Equatable {
  final String id;
  final String text;
  final int position;

  const ChecklistTemplateItem({
    required this.id,
    required this.text,
    this.position = 0,
  });

  factory ChecklistTemplateItem.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplateItem(
      id: (json['id'] ?? '').toString(),
      text: json['text']?.toString() ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, text, position];
}

class ChecklistTemplate extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? branchName;
  final bool isActive;
  final String? regulationText;
  final String? regulationName;
  final List<ChecklistTemplateItem> items;

  const ChecklistTemplate({
    required this.id,
    required this.name,
    this.description,
    this.branchName,
    this.isActive = true,
    this.regulationText,
    this.regulationName,
    this.items = const [],
  });

  factory ChecklistTemplate.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List? ?? [];
    return ChecklistTemplate(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      branchName: json['branch_name']?.toString(),
      isActive: json['is_active'] != false,
      regulationText: json['regulation_text']?.toString(),
      regulationName: json['regulation_name']?.toString(),
      items: itemsRaw
          .whereType<Map>()
          .map(
            (e) => ChecklistTemplateItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    branchName,
    isActive,
    regulationText,
    regulationName,
    items,
  ];
}

class ChecklistSummaryRow extends Equatable {
  final DateTime? runDate;
  final String checklistName;
  final String? branchName;
  final int doneCount;
  final int totalCount;
  final double percent;

  const ChecklistSummaryRow({
    this.runDate,
    required this.checklistName,
    this.branchName,
    required this.doneCount,
    required this.totalCount,
    required this.percent,
  });

  factory ChecklistSummaryRow.fromJson(Map<String, dynamic> json) {
    return ChecklistSummaryRow(
      runDate: json['run_date'] != null
          ? DateTime.tryParse(json['run_date'].toString())
          : null,
      checklistName: (json['checklist_name'] ?? '').toString(),
      branchName: json['branch_name']?.toString(),
      doneCount: (json['done_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    runDate,
    checklistName,
    branchName,
    doneCount,
    totalCount,
    percent,
  ];
}
