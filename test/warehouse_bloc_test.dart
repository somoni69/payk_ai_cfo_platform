import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/bloc/warehouse_bloc.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/bloc/warehouse_event.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/bloc/warehouse_state.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/domain/warehouse_models.dart';
import 'package:payk_ai_cfo_platform/features/warehouse/domain/warehouse_repository.dart';

class MockWarehouseRepository implements WarehouseRepository {
  List<WarehouseProduct> products = [];
  List<WarehouseMovement> movements = [];
  WarehouseSummaryData summary = const WarehouseSummaryData(
    productsCount: 0,
    totalStockValue: 0.0,
  );

  bool shouldFail = false;
  Completer<void>? loadGate;
  int productReads = 0;
  int movementReads = 0;
  int summaryReads = 0;

  @override
  Future<List<WarehouseProduct>> getProducts() async {
    productReads++;
    final gate = loadGate;
    if (gate != null) await gate.future;
    if (shouldFail) throw Exception('Get products error');
    return List.from(products);
  }

  @override
  Future<List<WarehouseMovement>> getMovements() async {
    movementReads++;
    final gate = loadGate;
    if (gate != null) await gate.future;
    if (shouldFail) throw Exception('Get movements error');
    return List.from(movements);
  }

  @override
  Future<WarehouseSummaryData> getSummary() async {
    summaryReads++;
    final gate = loadGate;
    if (gate != null) await gate.future;
    if (shouldFail) throw Exception('Get summary error');
    return summary;
  }

  @override
  Future<WarehouseProduct> createProduct(WarehouseProduct product) async {
    if (shouldFail) throw Exception('Create product error');
    final newProduct = product.copyWith(id: (products.length + 1).toString());
    products.add(newProduct);
    return newProduct;
  }

  @override
  Future<WarehouseMovement> createMovement(
    String productId,
    String direction,
    double qty,
    double amount,
    String? note,
  ) async {
    if (shouldFail) throw Exception('Create movement error');
    final movement = WarehouseMovement(
      id: (movements.length + 1).toString(),
      productId: productId,
      productName: 'Test Product',
      direction: direction,
      qty: qty,
      amount: amount,
      note: note,
      occurredAt: DateTime.now(),
    );
    movements.add(movement);
    return movement;
  }

  @override
  Future<WarehouseProduct> updateProduct(WarehouseProduct product) async {
    if (shouldFail) throw Exception('Update product error');
    final index = products.indexWhere((p) => p.id == product.id);
    if (index >= 0) products[index] = product;
    return product;
  }

  @override
  Future<void> deleteProduct(String id) async {
    if (shouldFail) throw Exception('Delete product error');
    products.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> zeroOutProduct(String id) async {
    if (shouldFail) throw Exception('Zero out error');
    final index = products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      products[index] = products[index].copyWith(stockQty: 0);
    }
  }

  List<WarehouseBatch> batches = [];

  @override
  Future<List<WarehouseBatch>> getBatches({bool expiringOnly = false}) async {
    if (shouldFail) throw Exception('Get batches error');
    if (expiringOnly) {
      return batches
          .where((b) => b.daysLeft != null && b.daysLeft! < 14)
          .toList();
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
    if (shouldFail) throw Exception('Create batch error');
    final batch = WarehouseBatch(
      id: '${batches.length + 1}',
      productId: productId,
      productName: 'Test Product',
      qty: qty,
      expiryDate: expiryDate,
      code: code,
      note: note,
      daysLeft: expiryDate?.difference(DateTime.now()).inDays,
    );
    batches.add(batch);
    return batch;
  }

  @override
  Future<WarehouseBatch> updateBatch({
    required String id,
    double? qty,
    DateTime? expiryDate,
    DateTime? receivedAt,
    String? code,
    String? note,
  }) async {
    if (shouldFail) throw Exception('Update batch error');
    final index = batches.indexWhere((b) => b.id == id);
    if (index < 0) {
      return WarehouseBatch(
        id: id,
        productId: '1',
        productName: 'x',
        qty: qty ?? 0,
      );
    }
    final current = batches[index];
    final updated = WarehouseBatch(
      id: current.id,
      productId: current.productId,
      productName: current.productName,
      unit: current.unit,
      code: code ?? current.code,
      qty: qty ?? current.qty,
      expiryDate: expiryDate ?? current.expiryDate,
      receivedAt: receivedAt ?? current.receivedAt,
      note: note ?? current.note,
      daysLeft: current.daysLeft,
      suggestedDiscount: current.suggestedDiscount,
    );
    batches[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteBatch(String id) async {
    if (shouldFail) throw Exception('Delete batch error');
    batches.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> applyBatchDiscount(String batchId, int percent) async {
    if (shouldFail) throw Exception('Discount error');
  }

  @override
  Future<WarehouseStockAnalysis> getStockAnalysis() async {
    if (shouldFail) throw Exception('Analysis error');
    return const WarehouseStockAnalysis(
      totalItems: 1,
      zeroItems: 0,
      stockValue: 1000,
      expiringCount: 0,
      expiredCount: 0,
      atRiskAmount: 0,
      summary: 'OK',
    );
  }

  @override
  Future<int> runExpiryCheck() async {
    if (shouldFail) throw Exception('Expiry check error');
    return 0;
  }

  @override
  Future<WarehouseProduct> assignBarcode(String productId) async {
    if (shouldFail) throw Exception('Assign barcode error');
    final index = products.indexWhere((p) => p.id == productId);
    final updated =
        (index >= 0
                ? products[index]
                : const WarehouseProduct(
                    id: '1',
                    name: 'Test',
                    unit: 'шт',
                    price: 10,
                    stockQty: 5,
                  ))
            .copyWith(barcode: '2001000000018');
    if (index >= 0) products[index] = updated;
    return updated;
  }

  @override
  Future<int> assignMissingBarcodes() async {
    if (shouldFail) throw Exception('Generate missing barcodes error');
    return 3;
  }

  @override
  Future<List<int>> downloadBarcodeLabelsPdf({
    required List<String> productIds,
    String sheet = 'a4',
    int copies = 1,
  }) async {
    if (shouldFail) throw Exception('Download labels PDF error');
    return [0x25, 0x50, 0x44, 0x46]; // '%PDF'
  }
}

void main() {
  group('WarehouseBloc Unit Tests', () {
    late MockWarehouseRepository repository;
    late WarehouseBloc bloc;
    late List<WarehouseProduct> initialProducts;

    setUp(() {
      repository = MockWarehouseRepository();
      initialProducts = [
        const WarehouseProduct(
          id: '1',
          name: 'Product 1',
          sku: 'SKU-001',
          unit: 'шт',
          price: 100.0,
          stockQty: 10.0,
        ),
      ];
      repository.products = List.from(initialProducts);
      repository.summary = const WarehouseSummaryData(
        productsCount: 1,
        totalStockValue: 1000.0,
      );
      bloc = WarehouseBloc(repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('Initial state is WarehouseLoading', () {
      expect(bloc.state, isA<WarehouseLoading>());
    });

    test('LoadWarehouseData emits WarehouseLoaded with mock data', () async {
      final expectedStates = [
        isA<WarehouseLoading>(),
        isA<WarehouseLoaded>()
            .having((s) => s.products.length, 'products list length', 1)
            .having((s) => s.summary.productsCount, 'products count', 1)
            .having((s) => s.summary.totalStockValue, 'stock value', 1000.0),
      ];

      expectLater(bloc.stream, emitsInOrder(expectedStates));
      bloc.add(LoadWarehouseData());
    });

    test(
      'LoadWarehouseData waits for network load and completes state',
      () async {
        bloc.add(LoadWarehouseData());
        await bloc.stream.firstWhere((state) => state is WarehouseLoaded);

        final gate = Completer<void>();
        repository.loadGate = gate;
        var completed = false;

        final future = bloc.stream.firstWhere(
          (state) => state is WarehouseLoaded,
        );
        future.then((_) => completed = true);
        bloc.add(LoadWarehouseData());

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(completed, false);

        gate.complete();
        await future;
        expect(completed, true);
      },
    );

    test(
      'movement synchronization starts products and summary reads together',
      () async {
        bloc.add(LoadWarehouseData());
        await bloc.stream.firstWhere((state) => state is WarehouseLoaded);

        final gate = Completer<void>();
        repository.loadGate = gate;
        bloc.add(
          const CreateMovementRequested(
            productId: '1',
            direction: 'income',
            qty: 1,
            amount: 100,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(repository.productReads, 2);
        expect(repository.summaryReads, 2);
        expect(repository.movementReads, 1);

        gate.complete();
        await bloc.stream.firstWhere(
          (state) => state is WarehouseLoaded && state.successMessage != null,
        );
      },
    );

    test(
      'failed movement rolls back without an extra products request',
      () async {
        bloc.add(LoadWarehouseData());
        await bloc.stream.firstWhere((state) => state is WarehouseLoaded);
        final productReadsBefore = repository.productReads;
        repository.shouldFail = true;

        bloc.add(
          const CreateMovementRequested(
            productId: '1',
            direction: 'income',
            qty: 1,
            amount: 100,
          ),
        );

        final failed =
            await bloc.stream.firstWhere(
                  (state) =>
                      state is WarehouseLoaded && state.errorMessage != null,
                )
                as WarehouseLoaded;
        expect(repository.productReads, productReadsBefore);
        expect(failed.products.single.stockQty, 10);
      },
    );

    test(
      'CreateProductRequested appends to list and updates summary',
      () async {
        bloc.add(LoadWarehouseData());
        await bloc.stream.firstWhere((s) => s is WarehouseLoaded);

        bloc.add(
          const CreateProductRequested(
            WarehouseProduct(
              id: '',
              name: 'Product 2',
              sku: 'SKU-002',
              unit: 'кг',
              price: 50.0,
              stockQty: 2.0,
            ),
          ),
        );

        final List<WarehouseState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 50));
        sub.cancel();

        expect(emitted, isNotEmpty);
        final loadedState = emitted.first as WarehouseLoaded;
        expect(loadedState.products.length, 2);
        expect(loadedState.products.last.name, 'Product 2');
        expect(loadedState.summary.productsCount, 2);
      },
    );

    test(
      'CreateMovementRequested optimistically updates quantities and updates server data',
      () async {
        bloc.add(LoadWarehouseData());
        await bloc.stream.firstWhere((s) => s is WarehouseLoaded);

        // Добавим приход 5 единиц первого товара
        bloc.add(
          const CreateMovementRequested(
            productId: '1',
            direction: 'income',
            qty: 5.0,
            amount: 500.0,
          ),
        );

        final List<WarehouseState> emitted = [];
        final sub = bloc.stream.listen(emitted.add);

        await Future.delayed(const Duration(milliseconds: 50));
        sub.cancel();

        expect(emitted, isNotEmpty);
        final firstLoaded = emitted.first as WarehouseLoaded;
        // Оптимистичное локальное количество: 10.0 + 5.0 = 15.0
        expect(
          firstLoaded.products.firstWhere((p) => p.id == '1').stockQty,
          15.0,
        );
      },
    );

    test(
      'AssignProductBarcodeRequested updates barcode in product and shows success',
      () async {
        bloc.add(LoadWarehouseData());
        await bloc.stream.firstWhere((s) => s is WarehouseLoaded);

        bloc.add(const AssignProductBarcodeRequested(productId: '1'));
        final loaded =
            await bloc.stream.firstWhere(
                  (s) =>
                      s is WarehouseLoaded && s.products.first.barcode != null,
                )
                as WarehouseLoaded;

        expect(loaded.products.first.barcode, '2001000000018');
        expect(loaded.successMessage, 'warehouse_barcode_assigned');
      },
    );

    test('DownloadBarcodeLabelsPdfRequested downloads PDF bytes', () async {
      bloc.add(LoadWarehouseData());
      await bloc.stream.firstWhere((s) => s is WarehouseLoaded);

      bloc.add(
        const DownloadBarcodeLabelsPdfRequested(
          productIds: ['1'],
          sheet: 'a4',
          copies: 2,
        ),
      );
      final loaded =
          await bloc.stream.firstWhere(
                (s) => s is WarehouseLoaded && s.pdfBytes != null,
              )
              as WarehouseLoaded;

      expect(loaded.pdfBytes, isNotEmpty);
      expect(loaded.isPdfDownloading, false);
    });
  });
}
