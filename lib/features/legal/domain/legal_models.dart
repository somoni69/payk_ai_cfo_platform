class TemplateVariable {
  final String key;
  final String label;

  const TemplateVariable({required this.key, required this.label});
}

class ContractTemplate {
  final String id;
  final String name;
  final String? category;
  final String body;
  final List<TemplateVariable> variables;

  const ContractTemplate({
    required this.id,
    required this.name,
    this.category,
    required this.body,
    required this.variables,
  });
}

class Law {
  final String id;
  final String title;
  final String? category;
  final String body;
  final String? sourceUrl;
  final DateTime createdAt;

  const Law({
    required this.id,
    required this.title,
    this.category,
    required this.body,
    this.sourceUrl,
    required this.createdAt,
  });
}

class LegalDeadline {
  final String id;
  final String title;
  final String type;
  final DateTime dueDate;
  final String? amount;
  final String? note;
  final bool isDone;
  final int? daysLeft;

  const LegalDeadline({
    required this.id,
    required this.title,
    required this.type,
    required this.dueDate,
    this.amount,
    this.note,
    required this.isDone,
    this.daysLeft,
  });

  LegalDeadline copyWith({
    String? id,
    String? title,
    String? type,
    DateTime? dueDate,
    String? amount,
    String? note,
    bool? isDone,
    int? daysLeft,
  }) {
    return LegalDeadline(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
      daysLeft: daysLeft ?? this.daysLeft,
    );
  }
}

class GeneratedContract {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  const GeneratedContract({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });
}
