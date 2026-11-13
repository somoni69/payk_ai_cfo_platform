import 'loyalty_models.dart';

abstract class LoyaltyRepository {
  Future<LoyaltyProgramState> program();

  Future<LoyaltyProgram> createProgram({
    required String title,
    required String slug,
  });

  Future<LoyaltyProgram> updateProgram({String? title, bool? enabled});

  Future<LoyaltyTerminal> createTerminal({
    required String name,
    required String formatCode,
  });

  Future<LoyaltyTerminal> updateTerminal(
    int id, {
    String? name,
    String? formatCode,
    bool? isActive,
    bool? coinEnabled,
  });

  Future<LoyaltyPosState> identify({
    required int terminalId,
    required String code,
  });

  Future<LoyaltyPosState> price(
    int previewId, {
    required String amount,
    required String billExtId,
    String? excludedAmount,
    String? cardAmount,
    bool wholesale = false,
  });

  Future<LoyaltyPosState> preview(int id);

  Future<LoyaltyPosState> suggestCoin(int id);

  Future<void> cancelPreview(int id);

  Future<Map<String, dynamic>> commit(
    int id, {
    required String key,
    required double expectedCash,
    required double expectedCoupon,
  });

  Future<Map<String, dynamic>> returnBill({
    required int terminalId,
    required String billExtId,
    String? amount,
    String? note,
  });

  Future<Map<String, dynamic>> startSms({
    required int terminalId,
    required String phone,
  });

  Future<LoyaltyPosState> confirmSms({
    required int terminalId,
    required String phone,
    required String code,
  });

  Future<void> lateAccrual({
    required int terminalId,
    required String phone,
    required String billExtId,
    required String amount,
    required String day,
  });

  Future<List<LoyaltyBillRow>> bills({int? terminalId});

  Future<LoyaltyMembersPage> members(MemberQuery query);

  Future<LoyaltyMemberCard> member(int id);

  Future<double> adjustMember(
    int id, {
    required String amount,
    required String reason,
  });

  Future<void> setWholesale(
    int id, {
    required String action,
    required String reason,
  });

  Future<List<LoyaltyBirthday>> birthdays({int days = 30, int? status});

  Future<List<LoyaltyMessageRow>> messages({int page = 1});

  Future<LoyaltyMessageSummary> messageSummary();

  Future<LoyaltyDashboard> dashboard();

  Future<List<IdentifiedSlice>> identified();

  Future<BroadcastPreview> previewBroadcast({
    required Map<String, String> filters,
    required String textTj,
    required String textRu,
  });

  Future<void> sendBroadcast({
    required Map<String, String> filters,
    required String textTj,
    required String textRu,
    required String clientKey,
  });
}
