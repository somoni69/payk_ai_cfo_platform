import 'package:intl/intl.dart';

const kPaykDemoUrl = 'https://payk-ecosystem.vercel.app/demo';

enum LeadStatus {
  incoming('new'),
  contacted('contacted'),
  meeting('meeting'),
  won('won'),
  lost('lost');

  final String apiValue;

  const LeadStatus(this.apiValue);

  static const valuesInOrder = <LeadStatus>[
    LeadStatus.incoming,
    LeadStatus.contacted,
    LeadStatus.meeting,
    LeadStatus.won,
    LeadStatus.lost,
  ];

  static LeadStatus parse(String? raw) {
    for (final status in values) {
      if (status.apiValue == raw) return status;
    }
    return LeadStatus.incoming;
  }

  String get labelKey => switch (this) {
    LeadStatus.incoming => 'leads_status_new',
    LeadStatus.contacted => 'leads_status_contacted',
    LeadStatus.meeting => 'leads_status_meeting',
    LeadStatus.won => 'leads_status_won',
    LeadStatus.lost => 'leads_status_lost',
  };
}

class DemoText {
  final String ru;
  final String tg;

  const DemoText({this.ru = '', this.tg = ''});

  factory DemoText.fromJson(dynamic raw) {
    if (raw is! Map) return const DemoText();
    return DemoText(
      ru: (raw['ru'] ?? '').toString(),
      tg: (raw['tg'] ?? '').toString(),
    );
  }

  String of(String lang) {
    if (lang == 'tg') return tg.isNotEmpty ? tg : ru;
    return ru.isNotEmpty ? ru : tg;
  }
}

class DemoChoice {
  final String key;
  final DemoText label;

  const DemoChoice({required this.key, required this.label});

  factory DemoChoice.fromJson(Map<String, dynamic> json) {
    return DemoChoice(
      key: (json['key'] ?? '').toString(),
      label: DemoText.fromJson(json['label']),
    );
  }
}

class DemoQuestion {
  final bool scored;
  final DemoText text;
  final List<DemoText> options;

  const DemoQuestion({
    required this.scored,
    required this.text,
    this.options = const [],
  });

  factory DemoQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return DemoQuestion(
      scored: json['scored'] == true,
      text: DemoText.fromJson(json['text']),
      options: rawOptions is List
          ? [for (final item in rawOptions) DemoText.fromJson(item)]
          : const [],
    );
  }
}

class DemoModule {
  final String key;
  final DemoText title;
  final List<DemoQuestion> questions;

  const DemoModule({
    required this.key,
    required this.title,
    this.questions = const [],
  });

  factory DemoModule.fromJson(Map<String, dynamic> json) {
    return DemoModule(
      key: (json['key'] ?? '').toString(),
      title: DemoText.fromJson(json['title']),
      questions: [
        for (final item in _maps(json['questions']))
          DemoQuestion.fromJson(item),
      ],
    );
  }
}

class DemoBank {
  final List<DemoModule> modules;
  final List<DemoChoice> roles;
  final List<DemoChoice> spheres;
  final List<DemoChoice> points;
  final List<DemoChoice> network;
  final List<DemoChoice> software;

  const DemoBank({
    this.modules = const [],
    this.roles = const [],
    this.spheres = const [],
    this.points = const [],
    this.network = const [],
    this.software = const [],
  });

  static const empty = DemoBank();

  factory DemoBank.fromJson(Map<String, dynamic> json) {
    return DemoBank(
      modules: [
        for (final item in _maps(json['modules'])) DemoModule.fromJson(item),
      ],
      roles: [
        for (final item in _maps(json['roles'])) DemoChoice.fromJson(item),
      ],
      spheres: [
        for (final item in _maps(json['spheres'])) DemoChoice.fromJson(item),
      ],
      points: [
        for (final item in _maps(json['points'])) DemoChoice.fromJson(item),
      ],
      network: [
        for (final item in _maps(json['network'])) DemoChoice.fromJson(item),
      ],
      software: [
        for (final item in _maps(json['software'])) DemoChoice.fromJson(item),
      ],
    );
  }

  String labelOf(List<DemoChoice> items, String? key, String lang) {
    if (key == null || key.isEmpty) return '—';
    for (final item in items) {
      if (item.key == key) return item.label.of(lang);
    }
    return key;
  }
}

class LeadAnswer {
  final int? option;
  final String? text;
  final int? ai;

  const LeadAnswer({this.option, this.text, this.ai});

  factory LeadAnswer.fromJson(Map<String, dynamic> json) {
    return LeadAnswer(
      option: _asInt(json['o']),
      text: _asString(json['t']),
      ai: _asInt(json['ai']),
    );
  }
}

class LeadModuleAnswers {
  final List<LeadAnswer> answers;
  final int? level;

  const LeadModuleAnswers({this.answers = const [], this.level});

  factory LeadModuleAnswers.fromJson(Map<String, dynamic> json) {
    return LeadModuleAnswers(
      answers: [
        for (final item in _maps(json['answers'])) LeadAnswer.fromJson(item),
      ],
      level: _asInt(json['level']),
    );
  }
}

class LeadRow {
  final int id;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final String name;
  final String phone;
  final String company;
  final String? role;
  final List<String> spheres;
  final int? years;
  final String lang;
  final String? points;
  final String? wantsNetwork;
  final List<String> software;
  final String? softwareOther;
  final int modulesDone;
  final int? overallLevel;
  final double? price;
  final LeadStatus status;
  final String? comment;
  final String? ref;
  final bool notified;
  final int repeats;

  const LeadRow({
    required this.id,
    required this.createdAt,
    this.lastSeenAt,
    required this.name,
    required this.phone,
    this.company = '',
    this.role,
    this.spheres = const [],
    this.years,
    this.lang = 'ru',
    this.points,
    this.wantsNetwork,
    this.software = const [],
    this.softwareOther,
    this.modulesDone = 0,
    this.overallLevel,
    this.price,
    required this.status,
    this.comment,
    this.ref,
    this.notified = false,
    this.repeats = 0,
  });

  factory LeadRow.fromJson(Map<String, dynamic> json) {
    return LeadRow(
      id: _asInt(json['id']) ?? 0,
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
      lastSeenAt: _asDate(json['last_seen_at']),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      role: _asString(json['role']),
      spheres: _strings(json['spheres']),
      years: _asInt(json['years']),
      lang: (json['lang'] ?? 'ru').toString(),
      points: _asString(json['points']),
      wantsNetwork: _asString(json['wants_network']),
      software: _strings(json['software']),
      softwareOther: _asString(json['software_other']),
      modulesDone: _asInt(json['modules_done']) ?? 0,
      overallLevel: _asInt(json['overall_level']),
      price: json['price'] == null ? null : _asDouble(json['price']),
      status: LeadStatus.parse(json['status']?.toString()),
      comment: _asString(json['comment']),
      ref: _asString(json['ref']),
      notified: json['notified'] == true,
      repeats: _asInt(json['repeats']) ?? 0,
    );
  }
}

class LeadDetail extends LeadRow {
  final Map<String, LeadModuleAnswers> answers;

  const LeadDetail({
    required super.id,
    required super.createdAt,
    super.lastSeenAt,
    required super.name,
    required super.phone,
    super.company,
    super.role,
    super.spheres,
    super.years,
    super.lang,
    super.points,
    super.wantsNetwork,
    super.software,
    super.softwareOther,
    super.modulesDone,
    super.overallLevel,
    super.price,
    required super.status,
    super.comment,
    super.ref,
    super.notified,
    super.repeats,
    this.answers = const {},
  });

  factory LeadDetail.fromJson(Map<String, dynamic> json) {
    final row = LeadRow.fromJson(json);
    final raw = json['answers'];
    final answers = <String, LeadModuleAnswers>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Map) {
          answers[key.toString()] = LeadModuleAnswers.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return LeadDetail(
      id: row.id,
      createdAt: row.createdAt,
      lastSeenAt: row.lastSeenAt,
      name: row.name,
      phone: row.phone,
      company: row.company,
      role: row.role,
      spheres: row.spheres,
      years: row.years,
      lang: row.lang,
      points: row.points,
      wantsNetwork: row.wantsNetwork,
      software: row.software,
      softwareOther: row.softwareOther,
      modulesDone: row.modulesDone,
      overallLevel: row.overallLevel,
      price: row.price,
      status: row.status,
      comment: row.comment,
      ref: row.ref,
      notified: row.notified,
      repeats: row.repeats,
      answers: answers,
    );
  }
}

class LeadSummary {
  final int total;
  final int today;
  final Map<String, int> byStatus;

  const LeadSummary({
    required this.total,
    required this.today,
    this.byStatus = const {},
  });

  static const empty = LeadSummary(total: 0, today: 0);

  int countOf(LeadStatus status) => byStatus[status.apiValue] ?? 0;

  factory LeadSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['by_status'];
    final byStatus = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        byStatus[key.toString()] = _asInt(value) ?? 0;
      });
    }
    return LeadSummary(
      total: _asInt(json['total']) ?? 0,
      today: _asInt(json['today']) ?? 0,
      byStatus: byStatus,
    );
  }
}

final _priceFormat = NumberFormat('#,##0', 'ru_RU');

String? formatLeadPrice(double? price) {
  if (price == null) return null;
  return _priceFormat.format(price.round());
}

String formatLeadYears(int? years, String lang, String lessYear) {
  if (years == null) return '—';
  if (years <= 0) return lessYear;
  if (lang == 'tg') return '$years сол';
  final tail = years.abs() % 100;
  if (tail >= 11 && tail <= 14) return '$years лет';
  final last = years.abs() % 10;
  if (last == 1) return '$years год';
  if (last >= 2 && last <= 4) return '$years года';
  return '$years лет';
}

String formatLeadDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _asDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String> _strings(dynamic raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) item.toString()];
}

List<Map<String, dynamic>> _maps(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}
