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
