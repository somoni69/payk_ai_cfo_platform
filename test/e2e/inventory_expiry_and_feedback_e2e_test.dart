import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/app_access.dart';
import 'package:payk_ai_cfo_platform/features/auth/domain/user_role.dart';
import 'package:payk_ai_cfo_platform/features/permissions/cubit/permissions_cubit.dart';
import 'package:payk_ai_cfo_platform/features/permissions/domain/my_permissions.dart';
import 'package:payk_ai_cfo_platform/features/permissions/domain/permissions_repository.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/bloc/warehouse_bloc.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/bloc/warehouse_event.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/bloc/warehouse_state.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/domain/warehouse_models.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/domain/warehouse_repository.dart';

class E2EWarehouseRepository implements WarehouseRepository {
  List<WarehouseProduct> products = [];
  List<WarehouseMovement> movements = [];
  List<WarehouseBatch> batches = [];
  WarehouseStockAnalysis? analysis;
  int discountAppliedPercent = 0;
  String? lastDiscountBatchId;

  @override
  Future<List<WarehouseProduct>> getProducts() async => List.from(products);

  @override
  Future<List<WarehouseMovement>> getMovements() async => List.from(movements);

  @override
  Future<WarehouseSummaryData> getSummary() async {
    final totalValue = products.fold<double>(
      0.0,
      (sum, p) => sum + (p.stockQty * (p.costPrice ?? p.price)),
    );
    return WarehouseSummaryData(
      productsCount: products.length,
      totalStockValue: totalValue,
    );
  }

  @override
  Future<List<WarehouseBatch>> getBatches({bool expiringOnly = false}) async {
    if (expiringOnly) {
      return batches.where((b) => (b.daysLeft ?? 999) <= 7).toList();
    }
    return List.from(batches);
  }

  @override
  Future<WarehouseBatch> createBatch({
    required String productId,
    required double qty,
    DateTime? expiryDate,
    String? code,
    String? note,
  }) async {
    final product = products.firstWhere((p) => p.id == productId);
    final daysLeft = expiryDate?.difference(DateTime.now().toUtc()).inDays;
    final newBatch = WarehouseBatch(
      id: 'batch-${batches.length + 1}',
      productId: productId,
      productName: product.name,
      qty: qty,
      expiryDate: expiryDate,
      daysLeft: daysLeft,
      suggestedDiscount: daysLeft != null && daysLeft <= 3 ? 30 : null,
    );
    batches.add(newBatch);
    return newBatch;
  }

  @override
  Future<int> runExpiryCheck() async {
    return 1;
  }

  @override
  Future<void> applyBatchDiscount(String batchId, int percent) async {
    lastDiscountBatchId = batchId;
    discountAppliedPercent = percent;
  }

  @override
  Future<WarehouseProduct> createProduct(WarehouseProduct product) async {
    products.add(product);
    return product;
  }

  @override
  Future<WarehouseMovement> createMovement(
    String productId,
    String direction,
    double qty,
    double amount,
    String? note,
  ) async {
    final prod = products.firstWhere((p) => p.id == productId);
    final newMove = WarehouseMovement(
      id: 'mov-${movements.length + 1}',
      productId: productId,
      productName: prod.name,
      direction: direction,
      qty: qty,
      amount: amount,
      occurredAt: DateTime.now().toUtc(),
      note: note,
    );
    movements.add(newMove);
    return newMove;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class E2EPermissionsRepository implements PermissionsRepository {
  MyPermissions permissions;
  E2EPermissionsRepository(this.permissions);

  @override
  Future<MyPermissions> getMyPermissions() async => permissions;
}

void main() {
  group(
    'Tier 4 Real-World E2E Scenario: Multi-Branch Inventory & Expiry Tracking with RBAC',
    () {
      late E2EWarehouseRepository warehouseRepository;
      late WarehouseBloc warehouseBloc;
      late PermissionsCubit permissionsCubit;

      final milkProduct = const WarehouseProduct(
        id: 'prod-1',
        name: 'Молоко Саодат 3.2%',
        unit: 'шт',
        price: 12.0,
        costPrice: 8.5,
        stockQty: 50.0,
        barcode: '4840001002003',
      );

      final warehouseManagerPerms = const MyPermissions(
        role: 'manager',
        isDirector: false,
        hidesMoney: false,
        modules: {
          'warehouse': ModulePerm(
            view: true,
            create: true,
            edit: true,
            delete: false,
            canAction: true,
          ),
        },
      );

      setUp(() {
        warehouseRepository = E2EWarehouseRepository();
        warehouseRepository.products = [milkProduct];
        warehouseBloc = WarehouseBloc(warehouseRepository);

        permissionsCubit = PermissionsCubit(
          E2EPermissionsRepository(warehouseManagerPerms),
        );
      });

      tearDown(() {
        warehouseBloc.close();
        permissionsCubit.close();
      });

      test(
        'E2E: RBAC Check -> Load Stock -> Create Expiring Batch -> Expiry Detection -> Apply Discount',
        () async {
          // Step 1: Verify user permissions to manage warehouse
          await permissionsCubit.load();
          expect(
            permissionsCubit.can(
              AppCapability.warehouse,
              action: PermAction.view,
              fallbackRole: UserRole.manager,
            ),
            isTrue,
          );
          expect(
            permissionsCubit.can(
              AppCapability.warehouse,
              action: PermAction.create,
              fallbackRole: UserRole.manager,
            ),
            isTrue,
          );
          expect(
            permissionsCubit.can(
              AppCapability.warehouse,
              action: PermAction.delete,
              fallbackRole: UserRole.manager,
            ),
            isFalse, // Manager cannot delete warehouse items
          );

          // Step 2: Load initial warehouse inventory
          warehouseBloc.add(LoadWarehouseData());
          var state =
              await warehouseBloc.stream.firstWhere((s) => s is WarehouseLoaded)
                  as WarehouseLoaded;
          expect(state.products.length, 1);
          expect(state.summary.productsCount, 1);
          expect(state.batches, isEmpty);

          // Step 3: Create a batch arriving with 3 days until expiry
          final nearExpiryDate = DateTime.now().toUtc().add(
            const Duration(days: 3),
          );
          warehouseBloc.add(
            CreateBatchRequested(
              productId: 'prod-1',
              qty: 20.0,
              expiryDate: nearExpiryDate,
              code: 'BATCH-2026-09-01-A',
              note: 'Партия с коротким сроком годности',
            ),
          );

          state =
              await warehouseBloc.stream.firstWhere(
                    (s) => s is WarehouseLoaded && s.batches.isNotEmpty,
                  )
                  as WarehouseLoaded;

          expect(state.batches.length, 1);
          expect(state.batches.first.daysLeft, lessThanOrEqualTo(3));
          expect(state.batches.first.suggestedDiscount, 30);

          // Step 4: Run batch expiry alerts trigger
          warehouseBloc.add(const RunExpiryCheckRequested());
          state =
              await warehouseBloc.stream.firstWhere(
                    (s) => s is WarehouseLoaded && s.successMessage != null,
                  )
                  as WarehouseLoaded;

          expect(state.successMessage, isNotEmpty);

          // Step 5: Apply suggested 30% discount on expiring batch
          warehouseBloc.add(
            const ApplyBatchDiscountRequested(batchId: 'batch-1', percent: 30),
          );

          state =
              await warehouseBloc.stream.firstWhere(
                    (s) => s is WarehouseLoaded && s.successMessage != null,
                  )
                  as WarehouseLoaded;

          expect(warehouseRepository.discountAppliedPercent, 30);
          expect(warehouseRepository.lastDiscountBatchId, 'batch-1');
          expect(state.successMessage, isNotEmpty);
        },
      );
    },
  );
}
