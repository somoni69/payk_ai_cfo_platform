import 'branch_models.dart';

abstract class BranchesRepository {
  Future<List<Branch>> getBranches();
  Future<Branch> createBranch({
    required String name,
    required String address,
    required String phone,
  });
  Future<Branch> updateBranch({
    required String id,
    required String name,
    required String address,
    required String phone,
    required bool isActive,
  });
  Future<void> deleteBranch(String id);
}
