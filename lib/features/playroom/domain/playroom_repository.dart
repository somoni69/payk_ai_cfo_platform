import '../../fin_ops/domain/fin_ops_models.dart';
import 'playroom_models.dart';

abstract class PlayroomRepository {
  Future<PlayroomTariff> getTariff();

  Future<PlayroomStats> getStats();

  Future<List<PlayroomOrder>> listOrders({
    String? day,
    bool active = false,
    String? query,
  });

  Future<PlayroomOrder> createOrder(PlayroomOrderInput input);

  Future<PlayroomOrder> extendOrder(int id, PlayroomExtendInput input);

  Future<PlayroomOrder> closeOrder(int id);

  Future<PlayroomOrder> cancelOrder(int id);

  Future<List<int>> downloadTicketPdf(int id, {required String format});

  Future<List<PlayroomRegister>> getRegisters();

  Future<List<PlayroomOpenShift>> getOpenShifts();

  Future<List<BankAccount>> getBanks();
}
