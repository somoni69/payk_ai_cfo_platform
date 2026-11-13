/// Расчёт чека в дирамах — те же шаги, что у сервера кассы
/// (`discount_cents`, `line_gross`, `allocate` в services/pos.py).
library;

int toCents(num value) {
  final negative = value < 0;
  final cents = ((value.abs() * 100) + 1e-8).round();
  return negative ? -cents : cents;
}

int toMilli(num qty) => ((qty.abs() * 1000) + 1e-8).round();

/// Округление num/den до целого, половина — вверх. Оба числа не отрицательные.
int divHalfUp(int numerator, int denominator) {
  if (denominator <= 0) return 0;
  return (2 * numerator + denominator) ~/ (2 * denominator);
}

/// Делит [total] пропорционально весам. Ничья — по порядку строк.
List<int> allocateCents(int total, List<int> weights) {
  final sum = weights.fold<int>(0, (acc, weight) => acc + weight);
  if (total <= 0 || sum <= 0) return List<int>.filled(weights.length, 0);
  final base = [for (final weight in weights) total * weight ~/ sum];
  final rem = total - base.fold<int>(0, (acc, part) => acc + part);
  final order = List<int>.generate(weights.length, (index) => index)
    ..sort((a, b) {
      final left = -((total * weights[a]) % sum);
      final right = -((total * weights[b]) % sum);
      final byRemainder = left.compareTo(right);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final index in order.take(rem)) {
    base[index] += 1;
  }
  return base;
}

class PosPriceLine {
  const PosPriceLine({
    required this.qty,
    required this.price,
    this.discountPercent,
  });

  final double qty;
  final double price;
  final double? discountPercent;
}

class PosCartPrice {
  const PosCartPrice({
    required this.totalCents,
    required this.receiptDiscountCents,
    required this.lineAmountsCents,
  });

  final int totalCents;
  final int receiptDiscountCents;

  /// Сумма строки уже после доли скидки на чек.
  final List<int> lineAmountsCents;

  double get total => totalCents / 100;

  double get receiptDiscount => receiptDiscountCents / 100;

  double lineAmount(int index) => lineAmountsCents[index] / 100;
}

int _percentOff(int base, double? percent) {
  if (percent == null || percent <= 0 || base <= 0) return 0;
  return divHalfUp(base * toCents(percent), 10000);
}

PosCartPrice pricePosCart({
  required List<PosPriceLine> lines,
  double? receiptDiscountPercent,
}) {
  final nets = <int>[];
  for (final line in lines) {
    final gross = divHalfUp(toCents(line.price) * toMilli(line.qty), 1000);
    final discount = _percentOff(gross, line.discountPercent);
    final net = gross - discount;
    nets.add(net < 0 ? 0 : net);
  }
  final sumNet = nets.fold<int>(0, (acc, net) => acc + net);
  final receipt = _percentOff(sumNet, receiptDiscountPercent);
  final shares = allocateCents(receipt > sumNet ? sumNet : receipt, nets);
  final amounts = <int>[];
  var total = 0;
  for (var i = 0; i < nets.length; i++) {
    final amount = nets[i] - shares[i];
    amounts.add(amount);
    total += amount;
  }
  return PosCartPrice(
    totalCents: total,
    receiptDiscountCents: receipt > sumNet ? sumNet : receipt,
    lineAmountsCents: amounts,
  );
}

String moneyApi(num value) => (toCents(value) / 100).toStringAsFixed(2);

String qtyApi(num qty) {
  final milli = toMilli(qty);
  final whole = milli ~/ 1000;
  final fraction = milli % 1000;
  if (fraction == 0) return '$whole';
  final digits = fraction
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$whole.$digits';
}

String newDocumentKey() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = Object().hashCode.toUnsigned(32).toRadixString(16);
  final key = '$time$salt';
  return key.length <= 64 ? key : key.substring(0, 64);
}
