/// Ответ на запрос "What-if" симуляции сценария.
class WhatIfResponseData {
  final String answer;

  const WhatIfResponseData({required this.answer});
}

/// Список идей, сгенерированных ИИ для маркетинговой кампании.
class AiIdeasResponseData {
  final List<String> ideas;

  const AiIdeasResponseData({required this.ideas});
}

class StrategicAnalysis {
  final String id;
  final String type; // 'swot', 'bcg', 'pestel'
  final String period;
  final Map<String, dynamic> data;
  final bool generatedByAi;
  final DateTime createdAt;

  const StrategicAnalysis({
    required this.id,
    required this.type,
    required this.period,
    required this.data,
    required this.generatedByAi,
    required this.createdAt,
  });
}

class MacroIndicator {
  final String id;
  final String name;
  final double value;
  final String? unit;
  final DateTime indicatorDate;

  const MacroIndicator({
    required this.id,
    required this.name,
    required this.value,
    this.unit,
    required this.indicatorDate,
  });
}

class StrategyScenario {
  final String id;
  final String quarter;
  final String title;
  final String content;

  const StrategyScenario({
    required this.id,
    required this.quarter,
    required this.title,
    required this.content,
  });
}

class DailySummary {
  final String date;
  final String summary;
  final bool generatedByAi;

  const DailySummary({
    required this.date,
    required this.summary,
    required this.generatedByAi,
  });
}

class NewsItem {
  final String title;
  final String url;
  final String source;
  final String? published;

  const NewsItem({
    required this.title,
    required this.url,
    required this.source,
    this.published,
  });
}

class NewsSource {
  final String code;
  final String name;
  final List<NewsItem> items;

  const NewsSource({
    required this.code,
    required this.name,
    this.items = const [],
  });
}
