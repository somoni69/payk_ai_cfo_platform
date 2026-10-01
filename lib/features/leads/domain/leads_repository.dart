import 'lead_models.dart';

abstract class LeadsRepository {
  Future<LeadSummary> getSummary();

  Future<List<LeadRow>> listLeads({String? query, String? status});

  Future<LeadDetail> getLead(int id);

  Future<LeadDetail> updateLead(
    int id, {
    required String status,
    required String comment,
  });

  Future<void> deleteLead(int id);

  Future<List<int>> exportXlsx({String? query, String? status});

  Future<DemoBank> getBank();
}
