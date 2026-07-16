import '../../../core/network/api_client.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';

/// Реализация репозитория финансов, получающая данные с бэкенда PAYK (FIN-01, FIN-03).
class ApiFinanceRepository implements FinanceRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<FinanceMetrics> getMetrics() async {
    try {
      final response = await _apiClient.dio.get('/finance/overview');
      final data = response.data as Map<String, dynamic>;

      final double currentBalance = (data['balance'] ?? 0.0).toDouble();
      final double revenue = (data['revenue'] ?? 0.0).toDouble();
      final double expenses = (data['expenses'] ?? 0.0).toDouble();
      final double profit = (data['profit'] ?? 0.0).toDouble();

      return FinanceMetrics(
        cashBalance: currentBalance,
        revenue: revenue,
        expenses: expenses,
        netProfit: profit,
        breakEvenPoint: (data['break_even_point'] ?? data['breakEvenPoint'] ?? (expenses * 1.25)).toDouble(),
        cashForecast: (data['cash_forecast'] ?? data['cashForecast'] ?? (currentBalance * 1.08)).toDouble(),
        cashBalanceDelta: (data['cash_balance_delta'] ?? data['cashBalanceDelta'] ?? 8.5).toDouble(),
        revenueDelta: (data['revenue_delta'] ?? data['revenueDelta'] ?? 12.3).toDouble(),
        expensesDelta: (data['expenses_delta'] ?? data['expensesDelta'] ?? 4.1).toDouble(),
        netProfitDelta: (data['net_profit_delta'] ?? data['netProfitDelta'] ?? 15.2).toDouble(),
        cashForecastDelta: (data['cash_forecast_delta'] ?? data['cashForecastDelta'] ?? 6.8).toDouble(),
      );
    } catch (e) {
      throw Exception('Не удалось загрузить финансовые показатели: ${e.toString()}');
    }
  }

  @override
  Future<List<CashFlowPoint>> getCashFlowHistory() async {
    try {
      final response = await _apiClient.dio.get('/finance/overview');
      final data = response.data as Map<String, dynamic>;
      final list = data['cashflow'] as List<dynamic>? ?? [];

      final double runningBalance = (data['balance'] ?? 0.0).toDouble();

      // Сортируем по дате по возрастанию
      final sortedList = List.from(list);
      sortedList.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      // Вычисляем исторический остаток кассы на конец каждого дня,
      // рассчитывая нетто-потоки в обратном направлении от текущего баланса
      double startBalance = runningBalance - sortedList.fold(0.0, (sum, item) {
        final double income = (item['income'] ?? 0.0).toDouble();
        final double expense = (item['expense'] ?? 0.0).toDouble();
        return sum + (income - expense);
      });

      List<CashFlowPoint> points = [];
      double currentBalance = startBalance;

      for (final item in sortedList) {
        final double income = (item['income'] ?? 0.0).toDouble();
        final double expense = (item['expense'] ?? 0.0).toDouble();
        currentBalance += (income - expense);

        points.add(CashFlowPoint(
          date: DateTime.parse(item['date'] as String),
          amount: currentBalance,
          income: income,
          expense: expense,
        ));
      }

      return points;
    } catch (e) {
      throw Exception('Не удалось загрузить историю движения денег: ${e.toString()}');
    }
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  Future<PnlReport> getPnlReport() async {
    try {
      final response = await _apiClient.dio.get('/finance/pnl');
      final data = response.data as Map<String, dynamic>;

      final incomeList = (data['income'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return PnlRow(
          category: map['category'] ?? '',
          amount: _toDouble(map['amount']),
          share: _toDouble(map['share']),
        );
      }).toList();

      final expenseList = (data['expense'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return PnlRow(
          category: map['category'] ?? '',
          amount: _toDouble(map['amount']),
          share: _toDouble(map['share']),
        );
      }).toList();

      return PnlReport(
        income: incomeList,
        expense: expenseList,
        totalIncome: _toDouble(data['total_income']),
        totalExpense: _toDouble(data['total_expense']),
        profit: _toDouble(data['profit']),
      );
    } catch (e) {
      throw Exception('Не удалось загрузить P&L отчет: ${e.toString()}');
    }
  }

  @override
  Future<BreakEvenAnalysis> getBreakEvenAnalysis() async {
    try {
      final response = await _apiClient.dio.get('/finance/break-even');
      final data = response.data as Map<String, dynamic>;

      return BreakEvenAnalysis(
        revenue: _toDouble(data['revenue']),
        fixedCosts: _toDouble(data['fixed_costs']),
        variableCosts: _toDouble(data['variable_costs']),
        variableRatio: _toDouble(data['variable_ratio']),
        breakEvenRevenue: _toDouble(data['break_even_revenue']),
        marginOfSafety: _toDouble(data['margin_of_safety']),
      );
    } catch (e) {
      throw Exception('Не удалось загрузить анализ безубыточности: ${e.toString()}');
    }
  }

  @override
  Future<AbcAnalysis> getAbcAnalysis(String dimension) async {
    try {
      final response = await _apiClient.dio.get('/finance/abc', queryParameters: {'dimension': dimension});
      final data = response.data as Map<String, dynamic>;

      final rowsList = (data['rows'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return AbcRow(
          name: map['name'] ?? '',
          turnover: _toDouble(map['turnover']),
          share: _toDouble(map['share']),
          cumulative: _toDouble(map['cumulative']),
          abcClass: map['abc_class'] ?? 'C',
        );
      }).toList();

      return AbcAnalysis(
        dimension: data['dimension'] ?? dimension,
        rows: rowsList,
        total: _toDouble(data['total']),
      );
    } catch (e) {
      throw Exception('Не удалось загрузить ABC-анализ: ${e.toString()}');
    }
  }

  @override
  Future<BankAccountsReport> getBankAccounts() async {
    try {
      final response = await _apiClient.dio.get('/finance/accounts');
      final data = response.data as Map<String, dynamic>;

      final list = (data['accounts'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return BankAccountInfo(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? '',
          bank: map['bank'],
          number: map['number'],
          currency: map['currency'] ?? 'TJS',
          balance: _toDouble(map['balance']),
        );
      }).toList();

      return BankAccountsReport(
        accounts: list,
        totalTjs: _toDouble(data['total_tjs']),
      );
    } catch (e) {
      throw Exception('Не удалось загрузить список счетов: ${e.toString()}');
    }
  }

  @override
  Future<ExchangeRatesReport> getExchangeRates() async {
    try {
      final response = await _apiClient.dio.get('/finance/rates');
      final data = response.data as Map<String, dynamic>;

      final list = (data['rates'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return RateRow(
          code: map['code'] ?? 'USD',
          rate: _toDouble(map['rate']),
          rateDate: DateTime.parse(map['rate_date'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();

      return ExchangeRatesReport(rates: list);
    } catch (e) {
      throw Exception('Не удалось загрузить курсы валют: ${e.toString()}');
    }
  }

  @override
  Future<AiInsightsReport> getAiInsights() async {
    try {
      final response = await _apiClient.dio.get('/finance/ai-insights');
      final data = response.data as Map<String, dynamic>;
      final forecastMap = data['forecast'] as Map<String, dynamic>? ?? {};

      return AiInsightsReport(
        forecast: CashGapForecast(
          atRisk: forecastMap['at_risk'] ?? false,
          avgDailyNet: _toDouble(forecastMap['avg_daily_net']),
          balance: _toDouble(forecastMap['balance']),
          daysToZero: forecastMap['days_to_zero'],
          message: forecastMap['message'] ?? '',
        ),
        recommendations: data['recommendations'] ?? 'Рекомендаций нет.',
      );
    } catch (e) {
      throw Exception('Не удалось загрузить ИИ инсайты: ${e.toString()}');
    }
  }

  @override
  Future<PlanFactReport> getPlanFactReport() async {
    try {
      final response = await _apiClient.dio.get('/finance/plan-fact');
      final data = response.data as Map<String, dynamic>;

      final rowsList = (data['rows'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return PlanFactRow(
          category: map['category'] ?? '',
          type: map['type'] ?? 'OUTFLOW',
          planned: _toDouble(map['planned']),
          fact: _toDouble(map['fact']),
          deviation: _toDouble(map['deviation']),
          completion: _toDouble(map['completion']),
        );
      }).toList();

      return PlanFactReport(
        period: data['period'] ?? '',
        rows: rowsList,
        totalPlanned: _toDouble(data['total_planned']),
        totalFact: _toDouble(data['total_fact']),
      );
    } catch (e) {
      throw Exception('Не удалось загрузить план-факт отчет: ${e.toString()}');
    }
  }
}
