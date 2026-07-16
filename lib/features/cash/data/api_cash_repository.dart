import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/cash_repository.dart';
import '../domain/transaction_model.dart';

/// Реализация репозитория кассы, работающая с API-эндпоинтами бэкенда (CASH-*).
class ApiCashRepository implements CashRepository {
  final ApiClient _apiClient = ApiClient();

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Future<List<Transaction>> getTransactions() async {
    try {
      final response = await _apiClient.dio.get('/cash/operations');
      final body = response.data as Map<String, dynamic>;
      final list = body['items'] as List<dynamic>? ?? [];

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final String category = map['category'] ?? '';
        final String description = map['description'] ?? '';
        final String counterparty = map['counterparty'] ?? '';
        final String title = counterparty.isNotEmpty ? counterparty : (description.isNotEmpty ? description : 'Операция');

        return Transaction(
          id: (map['id'] ?? '').toString(),
          title: title,
          category: category,
          amount: _toDouble(map['amount']),
          isIncome: (map['type'] ?? map['is_income'] ?? 'income') == 'income',
          paymentMethod: PaymentMethod.fromLabel(map['payment_method'] ?? map['paymentMethod'] ?? 'Наличные'),
          dateTime: DateTime.parse(map['occurred_at'] ?? map['created_at'] ?? DateTime.now().toIso8601String()),
          cashierName: map['created_by'] != null ? 'Кассир #${map['created_by']}' : 'Система',
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить историю операций: ${e.toString()}');
    }
  }

  @override
  Future<Transaction> addTransaction(Transaction transaction) async {
    try {
      int registerId = 1;
      if (transaction.registerId != null) {
        registerId = int.tryParse(transaction.registerId!) ?? 1;
      } else {
        try {
          final regRes = await _apiClient.dio.get('/cash/registers');
          final regList = regRes.data as List<dynamic>;
          if (regList.isNotEmpty) {
            registerId = regList[0]['id'] as int? ?? 1;
          }
        } catch (_) {}
      }

      final payload = {
        'register_id': registerId,
        'type': transaction.isIncome ? 'income' : 'expense',
        'amount': transaction.amount.toStringAsFixed(2),
        'currency': 'TJS',
        'payment_method': transaction.paymentMethod.name,
        'category': transaction.category,
        'counterparty': transaction.title,
        'description': 'Создано с мобильного устройства',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _apiClient.dio.post('/cash/operations', data: payload);
      final map = response.data as Map<String, dynamic>;

      final String category = map['category'] ?? '';
      final String description = map['description'] ?? '';
      final String counterparty = map['counterparty'] ?? '';
      final String title = counterparty.isNotEmpty ? counterparty : (description.isNotEmpty ? description : 'Операция');

      return Transaction(
        id: (map['id'] ?? '').toString(),
        title: title,
        category: category,
        amount: _toDouble(map['amount']),
        isIncome: (map['type'] ?? 'income') == 'income',
        paymentMethod: PaymentMethod.fromLabel(map['payment_method'] ?? 'Наличные'),
        dateTime: DateTime.parse(map['occurred_at'] ?? map['created_at'] ?? DateTime.now().toIso8601String()),
        cashierName: map['created_by'] != null ? 'Кассир #${map['created_by']}' : 'Система',
      );
    } catch (e) {
      throw Exception('Не удалось добавить транзакцию: ${e.toString()}');
    }
  }

  @override
  Future<CashShift?> getActiveShift() async {
    try {
      final response = await _apiClient.dio.get('/cash/shifts');
      final list = response.data as List<dynamic>;
      
      // Ищем открытую смену (status == 'open' или closed_at == null)
      final openShiftMap = list.firstWhere(
        (item) {
          final m = item as Map<String, dynamic>;
          final status = m['status'] as String?;
          final isOpenBool = m['is_open'] ?? m['isOpen'];
          final closedAt = m['closed_at'];
          return status == 'open' || isOpenBool == true || closedAt == null;
        },
        orElse: () => null,
      );
      
      if (openShiftMap == null) return null;
      
      final map = openShiftMap as Map<String, dynamic>;
      return CashShift(
        id: (map['id'] ?? '').toString(),
        openedAt: DateTime.parse(map['opened_at'] ?? map['openedAt'] ?? DateTime.now().toIso8601String()),
        closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at']) : null,
        startingBalance: _toDouble(map['opening_balance'] ?? map['starting_balance']),
        endingBalance: map['closed_at'] != null 
            ? _toDouble(map['actual_balance'] ?? map['ending_balance']) 
            : null,
        isOpen: true,
        cashierName: map['cashier_name'],
        registerName: map['register_name'],
        difference: map['difference'] != null ? _toDouble(map['difference']) : null,
        status: map['status'] as String? ?? 'open',
        note: map['note'],
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Не удалось проверить статус смены: ${e.toString()}');
    } catch (e) {
      return null;
    }
  }

  @override
  Future<CashShift> openShift(double startingBalance) async {
    try {
      int registerId = 1;
      try {
        final regRes = await _apiClient.dio.get('/cash/registers');
        final regList = regRes.data as List<dynamic>;
        if (regList.isNotEmpty) {
          registerId = regList[0]['id'] as int? ?? 1;
        }
      } catch (_) {}

      final payload = {
        'register_id': registerId,
        'opening_balance': startingBalance,
      };

      final response = await _apiClient.dio.post('/cash/shifts/open', data: payload);
      final map = response.data as Map<String, dynamic>;

      return CashShift(
        id: (map['id'] ?? '').toString(),
        openedAt: DateTime.parse(map['opened_at'] ?? map['openedAt'] ?? DateTime.now().toIso8601String()),
        startingBalance: _toDouble(map['opening_balance'] ?? map['starting_balance']),
        isOpen: true,
        cashierName: map['cashier_name'],
        registerName: map['register_name'],
        difference: map['difference'] != null ? _toDouble(map['difference']) : null,
        status: map['status'] as String? ?? 'open',
        note: map['note'],
      );
    } catch (e) {
      throw Exception('Не удалось открыть смену: ${e.toString()}');
    }
  }

  @override
  Future<CashShift> closeShift(double endingBalance) async {
    try {
      final activeShift = await getActiveShift();
      if (activeShift == null || activeShift.id == null || activeShift.id!.isEmpty) {
        throw Exception('Нет активной открытой смены для закрытия.');
      }
      
      final shiftId = activeShift.id;
      final payload = {
        'actual_balance': endingBalance,
        'note': 'Закрыто с мобильного устройства',
      };

      final response = await _apiClient.dio.post('/cash/shifts/$shiftId/close', data: payload);
      final map = response.data as Map<String, dynamic>;

      return CashShift(
        id: (map['id'] ?? '').toString(),
        openedAt: DateTime.parse(map['opened_at'] ?? map['openedAt'] ?? DateTime.now().toIso8601String()),
        closedAt: DateTime.parse(map['closed_at'] ?? map['closedAt'] ?? DateTime.now().toIso8601String()),
        startingBalance: _toDouble(map['opening_balance'] ?? map['starting_balance']),
        endingBalance: _toDouble(map['actual_balance'] ?? map['ending_balance']),
        isOpen: false,
        cashierName: map['cashier_name'],
        registerName: map['register_name'],
        difference: map['difference'] != null ? _toDouble(map['difference']) : null,
        status: map['status'] as String? ?? 'closed',
        note: map['note'],
      );
    } catch (e) {
      throw Exception('Не удалось закрыть смену: ${e.toString()}');
    }
  }

  @override
  Future<List<CashSummary>> getSummary() async {
    try {
      final response = await _apiClient.dio.get('/cash/summary');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return CashSummary(
          registerId: (map['register_id'] ?? '').toString(),
          registerName: map['register_name'] ?? 'Касса',
          hasOpenShift: map['has_open_shift'] ?? false,
          income: _toDouble(map['income']),
          expense: _toDouble(map['expense']),
          net: _toDouble(map['net']),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить сводку касс: ${e.toString()}');
    }
  }

  @override
  Future<List<CashShift>> getShifts() async {
    try {
      final response = await _apiClient.dio.get('/cash/shifts');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final statusStr = map['status'] as String? ?? 'closed';
        return CashShift(
          id: (map['id'] ?? '').toString(),
          openedAt: DateTime.parse(map['opened_at'] ?? map['openedAt'] ?? DateTime.now().toIso8601String()),
          closedAt: map['closed_at'] != null ? DateTime.parse(map['closed_at']) : null,
          startingBalance: _toDouble(map['opening_balance'] ?? map['starting_balance']),
          endingBalance: map['closed_at'] != null ? _toDouble(map['actual_balance'] ?? map['ending_balance']) : null,
          isOpen: statusStr == 'open',
          cashierName: map['cashier_name'] ?? 'Кассир #${map['cashier_id'] ?? ''}',
          registerName: map['register_name'] ?? 'Касса #${map['register_id'] ?? ''}',
          difference: map['difference'] != null ? _toDouble(map['difference']) : null,
          status: statusStr,
          note: map['note'],
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить историю смен: ${e.toString()}');
    }
  }

  @override
  Future<List<CashRegister>> getRegisters() async {
    try {
      final response = await _apiClient.dio.get('/cash/registers');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return CashRegister(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? 'Касса',
          location: map['location'],
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить список касс: ${e.toString()}');
    }
  }
}
