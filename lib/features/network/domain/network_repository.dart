import 'network_models.dart';

abstract class NetworkRepository {
  /// Список магазинов для экрана входа (публичный).
  Future<List<LoginStore>> fetchLoginStores();

  /// Список магазинов сети со статусами и количеством сотрудников.
  Future<List<NetworkStore>> fetchStores();

  /// Сводные финансовые показатели (выручка, расходы, прибыль) по магазинам сети.
  Future<List<StoreSummaryRow>> fetchSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  /// Создание нового магазина с автоматическим назначением директора.
  Future<NetworkStore> createStore(StoreCreateInput input);

  /// Обновление параметров магазина (название, адрес, статус).
  Future<NetworkStore> updateStore(
    int id, {
    String? name,
    String? location,
    bool? isActive,
    List<int>? moduleIds,
  });

  Future<ModuleCatalog> fetchModuleCatalog();

  Future<List<ClientModule>> fetchModules();

  Future<ClientModule> saveModule({
    int? id,
    required String name,
    String? description,
    required List<String> sections,
  });

  Future<void> deleteModule(int id);

  /// Удаление магазина (физическое для пустых, деактивация для магазинов с данными).
  Future<StoreDeleteResult> deleteStore(int id);

  /// Сброс пароля директора магазина.
  Future<void> resetDirectorPassword(
    int id, {
    String? username,
    required String password,
  });

  /// Вход владельца сети в конкретный магазин без второго пароля.
  /// Возвращает модель [ActingStore].
  Future<ActingStore> enterStore(int storeId);

  /// Возврат владельца в корень сети (сброс действующего магазина).
  Future<void> leaveStore();

  /// Получить локально сохраненный действующий магазин.
  Future<ActingStore?> getActingStore();

  /// Очистить локально сохраненный действующий магазин.
  Future<void> clearActingStore();
}
