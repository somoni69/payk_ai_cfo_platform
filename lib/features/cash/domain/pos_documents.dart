import 'pos_pricing.dart';
import 'transaction_model.dart';

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

DateTime _time(dynamic value) =>
    DateTime.tryParse('${value ?? ''}')?.toLocal() ?? DateTime.now();

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

class PosReceiptLine {
  const PosReceiptLine({
    required this.movementId,
    required this.kind,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.qty,
    required this.price,
    required this.discount,
    required this.amount,
    required this.returnedQty,
    required this.toWriteoff,
  });

  final int movementId;
  final String kind;
  final int productId;
  final String productName;
  final String unit;
  final double qty;
  final double price;
  final double discount;
  final double amount;
  final double returnedQty;
  final bool toWriteoff;

  double get leftQty {
    final left = qty - returnedQty;
    if (left < 0) return 0;
    if (left > qty) return qty;
    return left;
  }

  factory PosReceiptLine.fromJson(Map<String, dynamic> json) {
    return PosReceiptLine(
      movementId: _int(json['movement_id']),
      kind: '${json['kind'] ?? 'sale'}',
      productId: _int(json['product_id']),
      productName: '${json['product_name'] ?? ''}',
      unit: '${json['unit'] ?? ''}',
      qty: _num(json['qty']),
      price: _num(json['price']),
      discount: _num(json['discount']),
      amount: _num(json['amount']),
      returnedQty: _num(json['returned_qty']),
      toWriteoff: json['to_writeoff'] == true,
    );
  }
}

class PosReceipt {
  const PosReceipt({
    required this.id,
    required this.receiptNo,
    required this.kind,
    required this.amount,
    required this.paymentMethod,
    required this.registerId,
    required this.registerName,
    required this.cashierName,
    required this.occurredAt,
    required this.linesCount,
    required this.returnState,
    required this.discountAmount,
    required this.comment,
    this.lines = const [],
    this.refundTotal = 0,
    this.saleTotal = 0,
  });

  final int id;
  final int? receiptNo;
  final String kind;
  final double amount;
  final String paymentMethod;
  final int registerId;
  final String? registerName;
  final String? cashierName;
  final DateTime occurredAt;
  final int linesCount;
  final String returnState;
  final double discountAmount;
  final String? comment;
  final List<PosReceiptLine> lines;
  final double refundTotal;
  final double saleTotal;

  bool get canAct => kind == 'sale' && returnState != 'full';

  factory PosReceipt.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return PosReceipt(
      id: _int(json['id']),
      receiptNo: json['receipt_no'] == null ? null : _int(json['receipt_no']),
      kind: '${json['pos_kind'] ?? 'sale'}',
      amount: _num(json['amount']),
      paymentMethod: '${json['payment_method'] ?? 'cash'}',
      registerId: _int(json['register_id']),
      registerName: json['register_name']?.toString(),
      cashierName: json['created_by_name']?.toString(),
      occurredAt: _time(json['occurred_at']),
      linesCount: _int(json['lines_count']),
      returnState: '${json['return_state'] ?? 'none'}',
      discountAmount: _num(json['discount_amount']),
      comment: json['comment']?.toString(),
      lines: rawLines is List
          ? [
              for (final item in rawLines)
                if (item is Map)
                  PosReceiptLine.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      refundTotal: _num(json['refund_total']),
      saleTotal: _num(json['sale_total']),
    );
  }
}

class PosReceiptPage {
  const PosReceiptPage({required this.items, required this.total});

  final List<PosReceipt> items;
  final int total;

  factory PosReceiptPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return PosReceiptPage(
      items: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  PosReceipt.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      total: _int(json['total']),
    );
  }
}

class WriteoffLine {
  const WriteoffLine({
    required this.productName,
    required this.unit,
    required this.qty,
    required this.cost,
  });

  final String productName;
  final String unit;
  final double qty;
  final double cost;

  factory WriteoffLine.fromJson(Map<String, dynamic> json) {
    return WriteoffLine(
      productName: '${json['product_name'] ?? ''}',
      unit: '${json['unit'] ?? ''}',
      qty: _num(json['qty']),
      cost: _num(json['cost']),
    );
  }
}

class WriteoffDoc {
  const WriteoffDoc({
    required this.id,
    required this.number,
    required this.reason,
    required this.comment,
    required this.totalCost,
    required this.author,
    required this.registerName,
    required this.returnReceiptNo,
    required this.occurredAt,
    required this.lines,
  });

  final int id;
  final int number;
  final String reason;
  final String? comment;
  final double totalCost;
  final String? author;
  final String? registerName;
  final int? returnReceiptNo;
  final DateTime occurredAt;
  final List<WriteoffLine> lines;

  factory WriteoffDoc.fromJson(Map<String, dynamic> json) {
    final raw = json['lines'];
    return WriteoffDoc(
      id: _int(json['id']),
      number: _int(json['number']),
      reason: '${json['reason'] ?? 'other'}',
      comment: json['comment']?.toString(),
      totalCost: _num(json['total_cost']),
      author: json['created_by_name']?.toString(),
      registerName: json['register_name']?.toString(),
      returnReceiptNo: json['return_receipt_no'] == null
          ? null
          : _int(json['return_receipt_no']),
      occurredAt: _time(json['occurred_at']),
      lines: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  WriteoffLine.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

class WriteoffPage {
  const WriteoffPage({
    required this.items,
    required this.total,
    required this.totalCost,
  });

  final List<WriteoffDoc> items;
  final int total;
  final double totalCost;

  factory WriteoffPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return WriteoffPage(
      items: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  WriteoffDoc.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      total: _int(json['total']),
      totalCost: _num(json['total_cost']),
    );
  }
}

class HeldCart {
  const HeldCart({
    required this.id,
    required this.registerId,
    required this.label,
    required this.lines,
    required this.receiptDiscount,
    required this.total,
    required this.createdByName,
    required this.createdAt,
    this.products = const [],
  });

  final int id;
  final int registerId;
  final String? label;
  final List<Map<String, dynamic>> lines;
  final Map<String, dynamic>? receiptDiscount;
  final double total;
  final String? createdByName;
  final DateTime createdAt;
  final List<SaleProduct> products;

  factory HeldCart.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final rawProducts = json['products'];
    return HeldCart(
      id: _int(json['id']),
      registerId: _int(json['register_id']),
      label: json['label']?.toString(),
      lines: rawLines is List
          ? [
              for (final item in rawLines)
                if (item is Map) Map<String, dynamic>.from(item),
            ]
          : const [],
      receiptDiscount: _map(json['receipt_discount']),
      total: _num(json['total']),
      createdByName: json['created_by_name']?.toString(),
      createdAt: _time(json['created_at']),
      products: rawProducts is List
          ? [
              for (final item in rawProducts)
                if (item is Map) _product(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

SaleProduct _product(Map<String, dynamic> json) {
  return SaleProduct(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    sku: json['sku']?.toString(),
    barcode: json['barcode']?.toString(),
    unit: '${json['unit'] ?? 'шт'}',
    price: _num(json['price']),
    stockQty: _num(json['stock_qty']),
    imageUrl: json['image_url']?.toString(),
  );
}

class PosSaleLine {
  const PosSaleLine({
    required this.productId,
    required this.qty,
    required this.price,
    this.discountPercent,
  });

  final int productId;
  final double qty;
  final double price;
  final double? discountPercent;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'qty': qtyApi(qty),
    'price': moneyApi(price),
    if (discountPercent != null && discountPercent! > 0)
      'discount': {'percent': moneyApi(discountPercent!)},
  };
}

class ReturnLineInput {
  const ReturnLineInput({
    required this.movementId,
    required this.qty,
    this.toWriteoff = false,
  });

  final int movementId;
  final double qty;
  final bool toWriteoff;

  Map<String, dynamic> toJson() => {
    'movement_id': movementId,
    'qty': qtyApi(qty),
    'to_writeoff': toWriteoff,
  };
}

/// Чеки, возвраты, обмены, списания, отложенные корзины и движения ящика.
abstract class PosDocumentsRepository {
  Future<PosReceipt> sell({
    required int registerId,
    required List<PosSaleLine> lines,
    required String paymentMethod,
    required double expectedTotal,
    double? cashAmount,
    int? bankId,
    double? receiptDiscountPercent,
    int? heldId,
    String? pin,
    required String requestId,
  });

  Future<PosReceiptPage> receipts({
    String? kind,
    int? number,
    String? barcode,
    int page = 1,
  });

  Future<PosReceipt> receipt(int id);

  Future<PosReceipt> returnReceipt({
    required int receiptId,
    required int registerId,
    required List<ReturnLineInput> lines,
    required String paymentMethod,
    String? writeoffReason,
    String? comment,
    String? pin,
    required String requestId,
  });

  Future<PosReceipt> exchangeReceipt({
    required int receiptId,
    required int registerId,
    required List<ReturnLineInput> lines,
    required List<PosSaleLine> newLines,
    required String paymentMethod,
    String? writeoffReason,
    String? comment,
    String? pin,
    required String requestId,
  });

  Future<WriteoffPage> writeoffs({String? reason, int page = 1});

  Future<WriteoffDoc> createWriteoff({
    int? registerId,
    required String reason,
    String? comment,
    required List<PosSaleLine> lines,
    String? pin,
  });

  Future<List<HeldCart>> heldCarts({int? registerId});

  Future<HeldCart> holdCart({
    required int registerId,
    String? label,
    required List<PosSaleLine> lines,
    double? receiptDiscountPercent,
  });

  Future<HeldCart> restoreHeld(int id);

  Future<void> archiveHeld(int id, {String? pin});

  Future<void> cashMove({
    required int registerId,
    required String direction,
    required double amount,
    required String comment,
    String? pin,
    required String requestId,
  });
}
