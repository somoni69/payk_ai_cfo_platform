/// One turn in the floating AI assistant history (`GET /assistant/history`).
class AssistantMessage {
  final int id;
  final String role; // user | assistant
  final String text;
  final DateTime createdAt;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  bool get isUser => role == 'user';
}

/// Backend modules that get their own history branch (web parity).
const Set<String> kAssistantModules = {
  'dashboard',
  'cash',
  'reports',
  'finance-ops',
  'finance',
  'warehouse',
  'crm',
  'hr',
  'tasks',
  'my-tasks',
  'checklists',
  'audit',
  'legal',
  'marketing',
  'strategy',
  'branches',
  'meta',
};

const String kAssistantGeneralModule = 'general';

/// Backend advice cache uses `tj`, not Flutter's `tg`.
String assistantAdviceLang(String languageCode) =>
    languageCode.toLowerCase() == 'tg' ? 'tj' : 'ru';

class AdviceGoal {
  final String title;
  final String value;
  final String text;

  const AdviceGoal({this.title = '', this.value = '', this.text = ''});
}

class AdvicePriority {
  final String title;
  final String text;

  const AdvicePriority({required this.title, this.text = ''});
}

class AdviceContent {
  final AdviceGoal? goal;
  final List<AdvicePriority> priorities;
  final String analysis;

  const AdviceContent({
    this.goal,
    this.priorities = const [],
    this.analysis = '',
  });

  bool get isEmpty =>
      goal == null && priorities.isEmpty && analysis.trim().isEmpty;
}

class AdviceResponse {
  final String status; // ready | empty
  final AdviceContent? content;
  final DateTime? generatedAt;

  const AdviceResponse({required this.status, this.content, this.generatedAt});

  bool get isReady => status == 'ready' && content != null && !content!.isEmpty;
}

/// Maps app route → assistant module key (unknown → general).
String assistantModuleForPath(String path) {
  final p = path.toLowerCase();
  if (p.startsWith('/cash')) return 'cash';
  if (p.startsWith('/reports')) return 'reports';
  if (p.startsWith('/fin-ops') || p.startsWith('/fin_ops')) {
    return 'finance-ops';
  }
  if (p.startsWith('/dashboard')) return 'finance';
  if (p.startsWith('/warehouse')) return 'warehouse';
  if (p.startsWith('/crm')) return 'crm';
  if (p.startsWith('/meta')) {
    return 'crm'; // Meta chats share CRM context/rights
  }
  if (p.startsWith('/hr')) return 'hr';
  if (p.startsWith('/tasks')) return 'tasks';
  if (p.startsWith('/checklists')) return 'checklists';
  if (p.startsWith('/audit')) return 'audit';
  if (p.startsWith('/legal')) return 'legal';
  if (p.startsWith('/marketing')) return 'marketing';
  if (p.startsWith('/strategy')) return 'strategy';
  if (p.startsWith('/branches')) return 'branches';
  if (p.startsWith('/notifications')) return kAssistantGeneralModule;
  if (p.startsWith('/users') || p.startsWith('/integrations')) {
    return kAssistantGeneralModule;
  }
  return kAssistantGeneralModule;
}
