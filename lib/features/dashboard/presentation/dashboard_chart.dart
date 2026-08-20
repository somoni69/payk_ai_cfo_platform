part of 'dashboard_screen.dart';

/// CustomPainter для отрисовки графиков прихода и расхода с заливкой.
class CashFlowChartPainter extends CustomPainter {
  final List<CashFlowPoint> points;
  final Color greenColor;
  final Color redColor;
  final Color gridColor;
  final Color surfaceColor;
  final TextStyle textStyle;
  final String thousandSuffix;
  final Locale locale;

  CashFlowChartPainter({
    required this.points,
    required this.greenColor,
    required this.redColor,
    required this.gridColor,
    required this.surfaceColor,
    required this.textStyle,
    required this.thousandSuffix,
    required this.locale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double width = size.width;

    const double chartLeft = 45.0;
    const double chartBottom = 155.0;
    const double chartTop = 10.0;
    final double chartWidth = width - chartLeft;
    final double chartHeight = chartBottom - chartTop;

    double maxVal = 1000.0;
    for (final p in points) {
      if (p.income > maxVal) maxVal = p.income;
      if (p.expense > maxVal) maxVal = p.expense;
    }

    double rangeY = maxVal * 1.15;
    if (rangeY < 10.0) rangeY = 10.0;

    final int len = points.length;
    final double stepX = chartWidth / (len - 1);

    final dashedPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final double ratio = i / 4.0;
      final double y = chartBottom - (ratio * chartHeight);
      final double val = ratio * rangeY;

      _drawDashedLine(
        canvas,
        Offset(chartLeft, y),
        Offset(width, y),
        dashedPaint,
      );

      final label = val >= 1000.0
          ? '${formatLocalizedNumberForLocale(val / 1000.0, locale, maximumFractionDigits: 0)} $thousandSuffix'
          : formatLocalizedNumberForLocale(
              val,
              locale,
              maximumFractionDigits: 0,
            );

      final textPainter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    final greenPath = Path();
    final redPath = Path();

    if (len > 0) {
      final double yGreen0 =
          chartBottom - ((points[0].income / rangeY) * chartHeight);
      greenPath.moveTo(chartLeft, yGreen0);

      final double yRed0 =
          chartBottom - ((points[0].expense / rangeY) * chartHeight);
      redPath.moveTo(chartLeft, yRed0);

      for (int i = 0; i < len - 1; i++) {
        final double x1 = chartLeft + i * stepX;
        final double yGreen1 =
            chartBottom - ((points[i].income / rangeY) * chartHeight);
        final double yRed1 =
            chartBottom - ((points[i].expense / rangeY) * chartHeight);

        final double x2 = chartLeft + (i + 1) * stepX;
        final double yGreen2 =
            chartBottom - ((points[i + 1].income / rangeY) * chartHeight);
        final double yRed2 =
            chartBottom - ((points[i + 1].expense / rangeY) * chartHeight);

        final double cx1 = x1 + (x2 - x1) / 2.0;
        final double cx2 = x1 + (x2 - x1) / 2.0;

        greenPath.cubicTo(cx1, yGreen1, cx2, yGreen2, x2, yGreen2);
        redPath.cubicTo(cx1, yRed1, cx2, yRed2, x2, yRed2);
      }
    }

    // Отрисовка сглаженной линии Прихода
    final greenLinePaint = Paint()
      ..color = greenColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(greenPath, greenLinePaint);

    // Отрисовка сглаженной линии Расхода
    final redLinePaint = Paint()
      ..color = redColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(redPath, redLinePaint);

    // Находим пиковые значения для отрисовки аккуратных фокусных точек
    int maxIncomeIndex = 0;
    double maxIncomeVal = points[0].income;
    int maxExpenseIndex = 0;
    double maxExpenseVal = points[0].expense;

    for (int i = 0; i < len; i++) {
      if (points[i].income > maxIncomeVal) {
        maxIncomeVal = points[i].income;
        maxIncomeIndex = i;
      }
      if (points[i].expense > maxExpenseVal) {
        maxExpenseVal = points[i].expense;
        maxExpenseIndex = i;
      }
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = surfaceColor;

    // Зеленая точка на пике прихода
    final double maxIncomeX = chartLeft + maxIncomeIndex * stepX;
    final double maxIncomeY =
        chartBottom - ((maxIncomeVal / rangeY) * chartHeight);
    final dotGreenStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = greenColor
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(maxIncomeX, maxIncomeY), 4.5, dotPaint);
    canvas.drawCircle(Offset(maxIncomeX, maxIncomeY), 4.5, dotGreenStrokePaint);

    // Красная точка на пике расходов
    final double maxExpenseX = chartLeft + maxExpenseIndex * stepX;
    final double maxExpenseY =
        chartBottom - ((maxExpenseVal / rangeY) * chartHeight);
    final dotRedStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = redColor
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(maxExpenseX, maxExpenseY), 4.5, dotPaint);
    canvas.drawCircle(Offset(maxExpenseX, maxExpenseY), 4.5, dotRedStrokePaint);

    // Отрисовка дат на X-оси (каждые 5 дней для предотвращения наложений)
    for (int i = 0; i < len; i++) {
      if (i % 5 == 0 || i == len - 1) {
        final p = points[i];
        final x = chartLeft + i * stepX;
        final dateStr = formatLocalizedDateTimeForLocale(
          p.date,
          locale,
          style: LocalizedDateTimeStyle.date,
        );

        final textPainter = TextPainter(
          text: TextSpan(text: dateStr, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, chartBottom + 6),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 3.0;
    const double dashSpace = 3.0;

    double startX = p1.dx;
    final double y = p1.dy;

    while (startX < p2.dx) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CashFlowChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.greenColor != greenColor ||
      oldDelegate.redColor != redColor ||
      oldDelegate.thousandSuffix != thousandSuffix ||
      oldDelegate.locale != locale;
}

class _AccountsRatesData {
  final BankAccountsReport accounts;
  final ExchangeRatesReport rates;

  const _AccountsRatesData(this.accounts, this.rates);
}
