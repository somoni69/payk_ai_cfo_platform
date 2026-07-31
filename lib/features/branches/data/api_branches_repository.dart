import '../../../core/network/api_client.dart';
import '../domain/branch_models.dart';
import '../domain/branches_repository.dart';

class ApiBranchesRepository implements BranchesRepository {
  final ApiClient _client;

  ApiBranchesRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<Branch> _mockBranches = [
    const Branch(
      id: 'br-1',
      name: 'Филиал «Центральный»',
      address: 'г. Душанбе, пр. Рудаки 45',
      phone: '+992 900 11 2233',
      isActive: true,
      registersCount: 3,
      employeesCount: 12,
    ),
    const Branch(
      id: 'br-2',
      name: 'Филиал «Сомони»',
      address: 'г. Душанбе, ул. И. Сомони 12',
      phone: '+992 918 44 5566',
      isActive: true,
      registersCount: 2,
      employeesCount: 8,
    ),
    const Branch(
      id: 'br-3',
      name: 'Точка «Худжанд»',
      address: 'г. Худжанд, ул. Ленина 88',
      phone: '+992 927 77 8899',
      isActive: true,
      registersCount: 1,
      employeesCount: 4,
    ),
  ];

  @override
  Future<List<Branch>> getBranches() async {
    try {
      final response = await _client.dio.get('/api/v1/branches');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((e) => Branch.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return List.from(_mockBranches);
  }

  @override
  Future<Branch> createBranch({
    required String name,
    required String address,
    required String phone,
  }) async {
    final newBranch = Branch(
      id: 'br-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: address,
      phone: phone,
      isActive: true,
      registersCount: 1,
      employeesCount: 1,
    );
    try {
      final response = await _client.dio.post(
        '/api/v1/branches',
        data: newBranch.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Branch.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    _mockBranches.add(newBranch);
    return newBranch;
  }

  @override
  Future<Branch> updateBranch({
    required String id,
    required String name,
    required String address,
    required String phone,
    required bool isActive,
  }) async {
    final updated = Branch(
      id: id,
      name: name,
      address: address,
      phone: phone,
      isActive: isActive,
    );
    try {
      final response = await _client.dio.put(
        '/api/v1/branches/$id',
        data: updated.toJson(),
      );
      if (response.statusCode == 200) {
        return Branch.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    final index = _mockBranches.indexWhere((b) => b.id == id);
    if (index != -1) {
      _mockBranches[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> deleteBranch(String id) async {
    try {
      await _client.dio.delete('/api/v1/branches/$id');
    } catch (_) {}
    _mockBranches.removeWhere((b) => b.id == id);
  }
}
