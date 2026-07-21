import '../domain/legal_models.dart';
import '../domain/legal_repository.dart';

class MockLegalRepository implements LegalRepository {
  final List<LegalDeadline> _mockDeadlines = [
    LegalDeadline(
      id: '1',
      title: 'Декларация по налогу на доходы (Упрощенная система)',
      type: 'TAX',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      amount: '1 200 TJS',
      note: 'Ежеквартальный отчет для субъектов малого бизнеса РТ.',
      isDone: false,
      daysLeft: 5,
    ),
    LegalDeadline(
      id: '2',
      title: 'Уплата социального налога за сотрудников',
      type: 'TAX',
      dueDate: DateTime.now().add(const Duration(days: 12)),
      amount: '4 850 TJS',
      note: 'Социальный налог 20% (для работодателей в РТ).',
      isDone: false,
      daysLeft: 12,
    ),
    LegalDeadline(
      id: '3',
      title: 'Продление договора аренды офиса',
      type: 'CONTRACT',
      dueDate: DateTime.now().add(const Duration(days: 25)),
      note: 'Необходимо согласовать с арендодателем продление на 12 месяцев.',
      isDone: true,
      daysLeft: 25,
    ),
  ];

  @override
  Future<List<ContractTemplate>> getTemplates({
    bool forceRefresh = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [
      ContractTemplate(
        id: '1',
        name: 'Договор купли-продажи товаров (РТ)',
        category: 'Продажи',
        body:
            'ДОГОВОР КУПЛИ-ПРОДАЖИ\n\nг. Душанбе, Республика Таджикистан\n\n'
            'Продавец: {seller}, с одной стороны, и Покупатель: {buyer}, с другой стороны, '
            'заключили настоящий договор о продаже товаров на сумму {price} сомони.',
        variables: [
          TemplateVariable(key: 'seller', label: 'ФИО / Наименование Продавца'),
          TemplateVariable(
            key: 'buyer',
            label: 'ФИО / Наименование Покупателя',
          ),
          TemplateVariable(key: 'price', label: 'Сумма сделки (сомони)'),
        ],
      ),
      ContractTemplate(
        id: '2',
        name: 'Трудовой договор сотрудника (РТ)',
        category: 'Кадры',
        body:
            'ТРУДОВОЙ ДОГОВОР\n\nРеспублика Таджикистан\n\n'
            'Работодатель принимает на работу сотрудника {employee} на должность {position} '
            'с установлением ежемесячного должностного оклада в размере {salary} сомони.',
        variables: [
          TemplateVariable(key: 'employee', label: 'ФИО Работника'),
          TemplateVariable(key: 'position', label: 'Должность'),
          TemplateVariable(key: 'salary', label: 'Размер оклада (сомони)'),
        ],
      ),
    ];
  }

  @override
  Future<GeneratedContract> generateContract(
    String templateId,
    Map<String, String> data,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final title = templateId == '1'
        ? 'Договор купли-продажи'
        : 'Трудовой договор';
    var body = templateId == '1'
        ? 'ДОГОВОР КУПЛИ-ПРОДАЖИ\n\nг. Душанбе, Республика Таджикистан\n\n'
              'Продавец: {seller}, с одной стороны, и Покупатель: {buyer}, с другой стороны, '
              'заключили настоящий договор о продаже товаров на сумму {price} сомони.'
        : 'ТРУДОВОЙ ДОГОВОР\n\nРеспублика Таджикистан\n\n'
              'Работодатель принимает на работу сотрудника {employee} на должность {position} '
              'с установлением ежемесячного должностного оклада в размере {salary} сомони.';

    data.forEach((key, val) {
      body = body.replaceAll('{$key}', val);
    });

    return GeneratedContract(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '$title (${data.values.firstOrNull ?? ""})',
      body: body,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<Law>> getLaws({bool forceRefresh = false}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [
      Law(
        id: '1',
        title: 'Налоговый кодекс РТ, Статья 289 (Упрощенный налоговый режим)',
        category: 'Налоги',
        body:
            'Объектом налогообложения для индивидуальных предпринимателей и юридических лиц, '
            'применяющих упрощенный налоговый режим, является валовой доход, полученный за отчетный период. '
            'Налоговая ставка составляет 6% для розничной торговли и 5% для производственной сферы.',
        sourceUrl: 'https://nalog.tj',
        createdAt: DateTime(2025, 1, 1),
      ),
      Law(
        id: '2',
        title: 'Трудовой кодекс РТ, Статья 54 (Режим рабочего времени)',
        category: 'Трудовое право',
        body:
            'Нормальная продолжительность рабочего времени в организациях Республики Таджикистан '
            'не может превышать 40 часов в неделю. Для работников с вредными условиями труда '
            'устанавливается сокращенная продолжительность — не более 35 часов в неделю.',
        sourceUrl: 'https://mehnat.tj',
        createdAt: DateTime(2025, 2, 1),
      ),
      Law(
        id: '3',
        title: 'Закон РТ о государственной регистрации юридических лиц и ИП',
        category: 'Корпоративное право',
        body:
            'Государственная регистрация юридических лиц и индивидуальных предпринимателей осуществляется '
            'по принципу «единого окна» в органах Налогового комитета при Правительстве Республики Таджикистан '
            'в течение 3 рабочих дней с момента подачи заявления.',
        sourceUrl: 'https://nalog.tj',
        createdAt: DateTime(2024, 6, 1),
      ),
    ];
  }

  @override
  Future<List<LegalDeadline>> getDeadlines({bool forceRefresh = false}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.from(_mockDeadlines);
  }

  @override
  Future<LegalDeadline> updateDeadlineStatus(
    String deadlineId,
    bool isDone,
  ) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _mockDeadlines.indexWhere((d) => d.id == deadlineId);
    if (index != -1) {
      final updated = _mockDeadlines[index].copyWith(isDone: isDone);
      _mockDeadlines[index] = updated;
      return updated;
    }
    throw Exception('Срок не найден');
  }

  @override
  Future<String> askAiLawyer(String question) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final q = question.toLowerCase();
    if (q.contains('налог') || q.contains('упрощен')) {
      return 'Согласно Налоговому кодексу РТ (Статья 289), субъекты упрощенной системы декларируют '
          'доходы ежеквартально до 15 числа следующего месяца. Ставка составляет 6% от оборота (или 5% при производстве).';
    } else if (q.contains('оклад') ||
        q.contains('зарплат') ||
        q.contains('трудов')) {
      return 'В соответствии с Трудовым кодексом Республики Таджикистан, выплата заработной платы должна производиться '
          'не реже одного раза в полмесяца. Трудовой договор должен быть оформлен в письменном виде в двух экземплярах.';
    } else {
      return 'На основе законодательства РТ: ваш запрос обрабатывается. Согласно общим нормам гражданского кодекса РТ, '
          'сделки между юридическими лицами должны совершаться в простой письменной форме.';
    }
  }
}
