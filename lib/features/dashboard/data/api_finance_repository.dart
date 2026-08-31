import 'package:dio/dio.dart';
import '../../../core/network/user_facing_error.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/expiring_request_cache.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';

/// Реализация репозитория финансов, получающая данные с бэкенда PAYK (FIN-01, FIN-03).
class ApiFinanceRepository implements FinanceRepository {
  ApiFinanceRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;
  static const _overviewTtl = Duration(seconds: 30);

  final _overviewCache = ExpiringRequestCache<Map<String, dynamic>>(
    ttl: _overviewTtl,
  );

  Future<Map<String, dynamic>> _getOverviewData() =>
      _overviewCache.get(() async {
        final response = await _dio.get('/finance/overview');
        return Map<String, dynamic>.from(response.data as Map);
      });

  @override
  Future<FinanceOverview> getOverview({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _overviewCache.invalidate();
    }
    final results = await Future.wait([getMetrics(), getCashFlowHistory()]);
    return FinanceOverview(
      metrics: results[0] as FinanceMetrics,
      history: results[1] as List<CashFlowPoint>,
    );
  }

  @override
  Future<FinanceMetrics> getMetrics() async {
    try {
      final data = await _getOverviewData();

      final double currentBalance =
          (data['balance'] ??
                  data['cash_balance'] ??
                  data['cashBalance'] ??
                  0.0)
              .toDouble();
      final double revenue = (data['revenue'] ?? 0.0).toDouble();
      final double expenses = (data['expenses'] ?? data['expense'] ?? 0.0)
          .toDouble();
      final double profit =
          (data['profit'] ??
                  data['net_profit'] ??
                  data['netProfit'] ??
                  (revenue - expenses))
              .toDouble();

      final deltasMap =
          (data['deltas'] as Map<String, dynamic>?) ??
          (data['growth'] as Map<String, dynamic>?) ??
          (data['changes'] as Map<String, dynamic>?) ??
          (data['percentages'] as Map<String, dynamic>?);

      final double? cashBalanceDelta = _toOptionalDouble(
        data['cash_balance_delta'] ??
            data['cashBalanceDelta'] ??
            data['balance_delta'] ??
            data['balanceDelta'] ??
            data['cash_balance_growth'] ??
            data['balance_growth'] ??
            data['cash_balance_change'] ??
            deltasMap?['cash_balance'] ??
            deltasMap?['balance'],
      );

      final double? revenueDelta = _toOptionalDouble(
        data['revenue_delta'] ??
            data['revenueDelta'] ??
            data['revenue_growth'] ??
            data['revenue_change'] ??
            deltasMap?['revenue'],
      );

      final double? expensesDelta = _toOptionalDouble(
        data['expenses_delta'] ??
            data['expensesDelta'] ??
            data['expense_delta'] ??
            data['expenseDelta'] ??
            data['expenses_growth'] ??
            data['expense_growth'] ??
            data['expenses_change'] ??
            deltasMap?['expenses'] ??
            deltasMap?['expense'],
      );

      final double? netProfitDelta = _toOptionalDouble(
        data['net_profit_delta'] ??
            data['netProfitDelta'] ??
            data['profit_delta'] ??
            data['profitDelta'] ??
            data['profit_growth'] ??
            data['profit_change'] ??
            deltasMap?['net_profit'] ??
            deltasMap?['profit'],
      );

      final double? breakEvenPoint = _toOptionalDouble(
        data['break_even_point'] ?? data['breakEvenPoint'] ?? data['breakeven'],
      );

      final double? cashForecast = _toOptionalDouble(
        data['cash_forecast'] ?? data['cashForecast'] ?? data['forecast'],
      );

      final double? cashForecastDelta = _toOptionalDouble(
        data['cash_forecast_delta'] ??
            data['cashForecastDelta'] ??
            data['forecast_delta'] ??
            data['forecastDelta'] ??
            data['forecast_growth'] ??
            data['forecast_change'] ??
            deltasMap?['cash_forecast'] ??
            deltasMap?['forecast'],
      );

      return FinanceMetrics(
        cashBalance: currentBalance,
        revenue: revenue,
        expenses: expenses,
        netProfit: profit,
        breakEvenPoint: breakEvenPoint,
        cashForecast: cashForecast,
        cashBalanceDelta: cashBalanceDelta,
        revenueDelta: revenueDelta,
        expensesDelta: expensesDelta,
        netProfitDelta: netProfitDelta,
        cashForecastDelta: cashForecastDelta,
        operationsCount: (data['operations_count'] as num?)?.toInt() ?? 0,
        avgCheck: _toDouble(data['avg_check'] ?? data['avgCheck']),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<CashFlowPoint>> getCashFlowHistory() async {
    try {
      final data = await _getOverviewData();
      final list = data['cashflow'] as List<dynamic>? ?? [];

      final double runningBalance = (data['balance'] ?? 0.0).toDouble();

      // Сортируем по дате по возрастанию
      final sortedList = List.from(list);
      sortedList.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

      // Вычисляем исторический остаток кассы на конец каждого дня,
      // рассчитывая нетто-потоки в обратном направлении от текущего баланса
      double startBalance =
          runningBalance -
          sortedList.fold(0.0, (sum, item) {
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

        points.add(
          CashFlowPoint(
            date: DateTime.parse(item['date'] as String),
            amount: currentBalance,
            income: income,
            expense: expense,
          ),
        );
      }

      return points;
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  double? _toOptionalDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> _dateQuery(DateTime? dateFrom, DateTime? dateTo) {
    return {
      if (dateFrom != null)
        'date_from':
            '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}',
      if (dateTo != null)
        'date_to':
            '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}',
    };
  }

  @override
  Future<MetricBreakdown> getBreakdown(String metric) async {
    try {
      final response = await _dio.get('/finance/breakdown/$metric');
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final rows = (data['rows'] as List<dynamic>? ?? []).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return MetricBreakdownRow(
          label: (map['label'] ?? '').toString(),
          value: _toDouble(map['value']),
          share: _toDouble(map['share']),
        );
      }).toList();
      return MetricBreakdown(
        metric: (data['metric'] ?? metric).toString(),
        value: _toDouble(data['value']),
        period: (data['period'] ?? '').toString(),
        rows: rows,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<PnlReport> getPnlReport({DateTime? dateFrom, DateTime? dateTo}) async {
    try {
      final response = await _dio.get(
        '/finance/pnl',
        queryParameters: _dateQuery(dateFrom, dateTo),
      );
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<BreakEvenAnalysis> getBreakEvenAnalysis({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final response = await _dio.get(
        '/finance/break-even',
        queryParameters: _dateQuery(dateFrom, dateTo),
      );
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<AbcAnalysis> getAbcAnalysis(
    String dimension, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final apiDimension = AbcDimensions.toApi(dimension);
      final response = await _dio.get(
        '/finance/abc',
        queryParameters: {
          'dimension': apiDimension,
          ..._dateQuery(dateFrom, dateTo),
        },
      );
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
        dimension: AbcDimensions.toApi(
          (data['dimension'] ?? apiDimension).toString(),
        ),
        rows: rowsList,
        total: _toDouble(data['total']),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<BankAccountsReport> getBankAccounts() async {
    try {
      final response = await _dio.get('/finance/accounts');
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ExchangeRatesReport> getExchangeRates() async {
    try {
      final response = await _dio.get('/finance/rates');
      final data = response.data as Map<String, dynamic>;

      final list = (data['rates'] as List<dynamic>? ?? []).map((e) {
        final map = e as Map<String, dynamic>;
        return RateRow(
          code: map['code'] ?? 'USD',
          rate: _toDouble(map['rate']),
          rateDate: DateTime.parse(
            map['rate_date'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();

      return ExchangeRatesReport(rates: list);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<CurrencyBoard> getCurrencyBoard() async {
    try {
      final response = await _dio.get('/finance/currency-board');
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final official = (data['official'] as List<dynamic>? ?? []).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return RateRow(
          code: (map['code'] ?? 'USD').toString(),
          rate: _toDouble(map['rate']),
          rateDate:
              DateTime.tryParse(
                (map['rate_date'] ?? map['rateDate'] ?? '').toString(),
              ) ??
              DateTime.now(),
        );
      }).toList();
      final banks = (data['banks'] as List<dynamic>? ?? []).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        final fetched = map['fetched_at'] ?? map['fetchedAt'];
        return BankRateQuote(
          bank: (map['bank'] ?? '').toString(),
          bankName: (map['bank_name'] ?? map['bankName'] ?? map['bank'] ?? '')
              .toString(),
          currency: (map['currency'] ?? '').toString(),
          buy: map['buy'] == null ? null : _toDouble(map['buy']),
          sell: map['sell'] == null ? null : _toDouble(map['sell']),
          fetchedAt: fetched is String ? DateTime.tryParse(fetched) : null,
        );
      }).toList();
      return CurrencyBoard(official: official, banks: banks);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<AiInsightsReport> getAiInsights() async {
    try {
      final response = await _dio.get(
        '/finance/ai-insights',
        options: ApiClient.longRunningOptions(),
      );
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<PlanFactReport> getPlanFactReport({String? period}) async {
    try {
      final response = await _dio.get(
        '/finance/plan-fact',
        queryParameters: {
          if (period != null && period.isNotEmpty) 'period': period,
        },
      );
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
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<ClientAnalysisReport> getClientAnalysis() async {
    try {
      final response = await _dio.get('/finance/clients');
      final data = response.data as Map<String, dynamic>;
      ClientAnalysisRow mapRow(Map<String, dynamic> map) {
        return ClientAnalysisRow(
          name: map['name']?.toString() ?? '',
          purchases: (map['purchases'] as num?)?.toInt() ?? 0,
          total: _toDouble(map['total']),
          lastPurchase: map['last_purchase'] != null
              ? DateTime.tryParse(map['last_purchase'].toString())
              : null,
          daysSince: (map['days_since'] as num?)?.toInt(),
        );
      }

      return ClientAnalysisReport(
        frequent: (data['frequent'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => mapRow(Map<String, dynamic>.from(e)))
            .toList(),
        dormant: (data['dormant'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => mapRow(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<PlanItem> createPlan({
    required String period,
    required String category,
    required String type,
    required double plannedAmount,
  }) async {
    try {
      final response = await _dio.post(
        '/finance/plans',
        data: {
          'period': period,
          'category': category,
          'type': type,
          'planned_amount': plannedAmount,
        },
      );
      final map = response.data as Map<String, dynamic>;
      return PlanItem(
        id: (map['id'] as num?)?.toInt() ?? 0,
        period: map['period']?.toString() ?? period,
        category: map['category']?.toString() ?? category,
        type: map['type']?.toString() ?? type,
        plannedAmount: _toDouble(map['planned_amount']),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deletePlan(int planId) async {
    try {
      await _dio.delete('/finance/plans/$planId');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<BankAccountInfo> createAccount({
    required String name,
    String? bank,
    String? number,
    String currency = 'TJS',
    double balance = 0,
  }) async {
    try {
      final response = await _dio.post(
        '/finance/accounts',
        data: {
          'name': name,
          'bank': bank,
          'number': number,
          'currency': currency,
          'balance': balance,
        },
      );
      final map = response.data as Map<String, dynamic>;
      return BankAccountInfo(
        id: (map['id'] ?? '').toString(),
        name: map['name']?.toString() ?? name,
        bank: map['bank']?.toString(),
        number: map['number']?.toString(),
        currency: map['currency']?.toString() ?? currency,
        balance: _toDouble(map['balance']),
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    try {
      final id = int.tryParse(accountId);
      if (id == null || id <= 0) throw StateError(ErrorKeys.invalidId);
      await _dio.delete('/finance/accounts/$id');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<void> zeroOutAccount(String accountId) async {
    try {
      final id = int.tryParse(accountId);
      if (id == null || id <= 0) throw StateError(ErrorKeys.invalidId);
      await _dio.post(
        '/finance-ops/zero-out',
        data: {'target': 'account', 'id': id},
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<ConvertResult> convertAmount(double amount, String base) async {
    try {
      final response = await _dio.get(
        '/finance/convert',
        queryParameters: {'amount': amount, 'base': base},
      );
      final data = response.data as Map<String, dynamic>;
      final valuesRaw = data['values'];
      final values = <String, double>{};
      if (valuesRaw is Map) {
        valuesRaw.forEach((k, v) {
          values[k.toString()] = _toDouble(v);
        });
      }
      return ConvertResult(
        base: data['base']?.toString() ?? base,
        amount: _toDouble(data['amount']),
        values: values,
      );
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<void> refreshRates() async {
    try {
      await _dio.post('/finance/rates/refresh');
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }

  @override
  Future<OneCReconcileReport> getOneCReconcile({
    String? day,
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _dio.get(
        '/finance/onec/reconcile',
        queryParameters: day != null ? {'day': day} : null,
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return OneCReconcileReport.fromJson(data);
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<List<OneCTarget>> getOneCTargets({bool forceRefresh = false}) async {
    try {
      final response = await _dio.get('/finance/onec/targets');
      final list = response.data as List<dynamic>;
      return list
          .map((e) => OneCTarget.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.loadFailed));
    }
  }

  @override
  Future<void> saveOneCLink(OneCLinkInput input) async {
    try {
      await _dio.put('/finance/onec/link', data: input.toJson());
    } catch (e) {
      throw Exception(userFacingError(e, fallback: ErrorKeys.saveFailed));
    }
  }
}
