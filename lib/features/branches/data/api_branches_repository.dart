import '../../../core/network/api_client.dart';
import '../domain/branch_models.dart';
import '../domain/branches_repository.dart';

/// Branches repository. Offline fallbacks use localization keys for names/addresses.
class ApiBranchesRepository implements BranchesRepository {
  final ApiClient _client;

  ApiBranchesRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final List<Branch> _mockBranches = [
    const Branch(
      id: 'br-1',
      name: 'mock_branch_central',
      address: 'mock_address_central',
      phone: '+992 900 11 2233',
      isActive: true,
      registersCount: 3,
      employeesCount: 12,
    ),
    const Branch(
      id: 'br-2',
      name: 'mock_branch_somoni',
      address: 'mock_address_somoni',
      phone: '+992 918 44 5566',
      isActive: true,
      registersCount: 2,
      employeesCount: 8,
    ),
    const Branch(
      id: 'br-3',
      name: 'mock_branch_khujand',
      address: 'mock_address_khujand',
      phone: '+992 927 77 8899',
      isActive: true,
      registersCount: 1,
      employeesCount: 4,
    ),
  ];

  @override
  Future<List<Branch>> getBranches() async {
    try {
      final response = await _client.dio.get('/branches');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map((e) => Branch.fromJson(Map<String, dynamic>.from(e)))
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
        '/branches',
        data: {'name': name, 'address': address, 'phone': phone},
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
    final existing = _mockBranches.cast<Branch?>().firstWhere(
      (b) => b?.id == id,
      orElse: () => null,
    );
    final updated = Branch(
      id: id,
      name: name,
      address: address,
      phone: phone,
      isActive: isActive,
      registersCount: existing?.registersCount ?? 1,
      employeesCount: existing?.employeesCount ?? 1,
    );
    try {
      final response = await _client.dio.patch(
        '/branches/$id',
        data: {
          'name': name,
          'address': address,
          'phone': phone,
          'is_active': isActive,
        },
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
      await _client.dio.delete('/branches/$id');
    } catch (_) {}
    _mockBranches.removeWhere((b) => b.id == id);
  }
}
