import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_card.dart';

/// Легковесный системный виджет эффекта Shimmer (мерцания загрузки)
/// в полном соответствии с дизайн-системой Grounded Enterprise.
class LedgerShimmer extends StatefulWidget {
  final Widget child;

  const LedgerShimmer({super.key, required this.child});

  @override
  State<LedgerShimmer> createState() => _LedgerShimmerState();
}

class _LedgerShimmerState extends State<LedgerShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseColor = colors.border.withValues(alpha: 0.35);
    final highlightColor = colors.surface.withValues(alpha: 0.95);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final double value = _controller.value;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.0, 0.5, 1.0],
                transform: _SlidingGradientTransform(slidePercent: value),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.5 - 1.25),
      0,
      0,
    );
  }
}

/// Заполнитель блока (Box Placeholder) для Skeletal Loading.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.border.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Пилюля статуса / бейджа для скелетона.
class LedgerChipShimmer extends StatelessWidget {
  final double width;
  final double height;
  const LedgerChipShimmer({super.key, this.width = 64, this.height = 22});

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(width: width, height: height, borderRadius: 999);
  }
}

/// Строка карточки операции: заголовок + пилюля/категория + сумма.
class LedgerCardShimmer extends StatelessWidget {
  final double height;
  const LedgerCardShimmer({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ShimmerBox(width: 40, height: 40, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerBox(width: 140, height: 15, borderRadius: 4),
                SizedBox(height: 6),
                Row(
                  children: [
                    LedgerChipShimmer(width: 60, height: 18),
                    SizedBox(width: 6),
                    ShimmerBox(width: 80, height: 11, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(width: 76, height: 15, borderRadius: 4),
              SizedBox(height: 5),
              ShimmerBox(width: 48, height: 10, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Скелетон сводных метрик (две карточки в строке).
class LedgerStatsShimmer extends StatelessWidget {
  const LedgerStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 2,
          child: LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 80, height: 11, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 54, height: 24, borderRadius: 6),
              ],
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 100, height: 11, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 110, height: 24, borderRadius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Одна хаб-плитка: иконка 36×36, заголовок и подпись — как `_buildHubCard`.
class LedgerHubTileShimmer extends StatelessWidget {
  const LedgerHubTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 36, height: 36, borderRadius: 8),
          SizedBox(height: 10),
          ShimmerBox(width: 90, height: 14.5, borderRadius: 4),
          SizedBox(height: 4),
          ShimmerBox(width: 110, height: 12.5, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Сетка хаб-плиток 2 колонки; нечётная последняя — на всю ширину.
class LedgerHubGridShimmer extends StatelessWidget {
  final int count;
  final double gap;
  const LedgerHubGridShimmer({super.key, this.count = 4, this.gap = 10});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < count; i += 2) {
      if (i > 0) rows.add(SizedBox(height: gap));
      if (i + 1 < count) {
        rows.add(
          Row(
            children: [
              const Expanded(child: LedgerHubTileShimmer()),
              SizedBox(width: gap),
              const Expanded(child: LedgerHubTileShimmer()),
            ],
          ),
        );
      } else {
        rows.add(const LedgerHubTileShimmer());
      }
    }
    return Column(children: rows);
  }
}

/// Скелетон плашки внимания / статуса (с иконкой 36x36 и стрелкой).
class LedgerAttentionCardShimmer extends StatelessWidget {
  const LedgerAttentionCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          ShimmerBox(width: 36, height: 36, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 14.5, borderRadius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 190, height: 12.5, borderRadius: 4),
              ],
            ),
          ),
          ShimmerBox(width: 18, height: 18, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Скелетон кнопок быстрых действий (1 или 2 кнопки высотой 44px).
class LedgerQuickActionsShimmer extends StatelessWidget {
  final int count;
  const LedgerQuickActionsShimmer({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) {
    if (count == 1) {
      return const ShimmerBox(
        width: double.infinity,
        height: 44,
        borderRadius: 8,
      );
    }
    return const Row(
      children: [
        Expanded(child: ShimmerBox(height: 44, borderRadius: 8)),
        SizedBox(width: 8),
        Expanded(child: ShimmerBox(height: 44, borderRadius: 8)),
      ],
    );
  }
}

/// Скелетон заголовка ленты/списка с кнопкой «Все →».
class LedgerFeedHeaderShimmer extends StatelessWidget {
  final double titleWidth;
  const LedgerFeedHeaderShimmer({super.key, this.titleWidth = 140});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShimmerBox(width: titleWidth, height: 16, borderRadius: 4),
        const ShimmerBox(width: 80, height: 13, borderRadius: 4),
      ],
    );
  }
}

/// Скелетон Hero-карточки сводки.
class LedgerHeroCardShimmer extends StatelessWidget {
  final bool hasActionButton;
  const LedgerHeroCardShimmer({super.key, this.hasActionButton = false});

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 140, height: 13, borderRadius: 4),
              LedgerChipShimmer(width: 72, height: 20),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBox(width: 190, height: 26, borderRadius: 6),
          const SizedBox(height: 6),
          const ShimmerBox(width: 160, height: 12, borderRadius: 4),
          if (hasActionButton) ...[
            const SizedBox(height: 12),
            const ShimmerBox(
              width: double.infinity,
              height: 44,
              borderRadius: 8,
            ),
          ],
        ],
      ),
    );
  }
}

/// Hero хаба: подпись + чип, крупное значение, разделитель, строка метрик.
class LedgerHubStatsHeroShimmer extends StatelessWidget {
  final bool showProgress;
  const LedgerHubStatsHeroShimmer({super.key, this.showProgress = false});

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 140, height: 13, borderRadius: 4),
              LedgerChipShimmer(width: 64, height: 20),
            ],
          ),
          const SizedBox(height: 8),
          const ShimmerBox(width: 180, height: 26, borderRadius: 6),
          if (showProgress) ...[
            const SizedBox(height: 10),
            const ShimmerBox(
              width: double.infinity,
              height: 6,
              borderRadius: 4,
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Row(
            children: [
              ShimmerBox(width: 16, height: 16, borderRadius: 4),
              SizedBox(width: 6),
              ShimmerBox(width: 110, height: 13, borderRadius: 4),
              SizedBox(width: 6),
              ShimmerBox(width: 90, height: 13, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Баннер AI Studio: иконка 40×40, заголовок + чип, подпись, шеврон.
class LedgerStudioBannerShimmer extends StatelessWidget {
  const LedgerStudioBannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          ShimmerBox(width: 40, height: 40, borderRadius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 120, height: 14.5, borderRadius: 4),
                    SizedBox(width: 6),
                    LedgerChipShimmer(width: 44, height: 16),
                  ],
                ),
                SizedBox(height: 4),
                ShimmerBox(width: 180, height: 12.5, borderRadius: 4),
              ],
            ),
          ),
          ShimmerBox(width: 18, height: 18, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Карточка Meta webhook: статус, URL, подсказка.
class LedgerWebhookCardShimmer extends StatelessWidget {
  const LedgerWebhookCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 20, height: 20, borderRadius: 4),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 15, borderRadius: 4)),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 72, height: 20),
            ],
          ),
          SizedBox(height: 8),
          ShimmerBox(width: 180, height: 12, borderRadius: 4),
          SizedBox(height: 10),
          ShimmerBox(width: 90, height: 11, borderRadius: 4),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 13, borderRadius: 4)),
              SizedBox(width: 8),
              ShimmerBox(width: 18, height: 18, borderRadius: 4),
            ],
          ),
          SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Строка ленты: иконка, заголовок/подпись, сумма или чип.
class LedgerFeedRowShimmer extends StatelessWidget {
  final bool circularLeading;
  final bool showChip;
  const LedgerFeedRowShimmer({
    super.key,
    this.circularLeading = false,
    this.showChip = true,
  });

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ShimmerBox(
            width: circularLeading ? 40 : 36,
            height: circularLeading ? 40 : 36,
            borderRadius: circularLeading ? 999 : 8,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 130, height: 14, borderRadius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 90, height: 11, borderRadius: 4),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const ShimmerBox(width: 76, height: 14, borderRadius: 4),
              const SizedBox(height: 4),
              if (showChip)
                const LedgerChipShimmer(width: 54, height: 18)
              else
                const ShimmerBox(width: 48, height: 10, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Текстовый блок ответа ИИ / сводки.
class LedgerTextBlockShimmer extends StatelessWidget {
  const LedgerTextBlockShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 16, height: 16, borderRadius: 4),
              SizedBox(width: 6),
              ShimmerBox(width: 90, height: 12, borderRadius: 4),
            ],
          ),
          SizedBox(height: 10),
          ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: 220, height: 13, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: 160, height: 13, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Полный системный список скелетонов.
class LedgerListShimmer extends StatelessWidget {
  final int itemCount;
  final bool showStatsHeader;

  const LedgerListShimmer({
    super.key,
    this.itemCount = 6,
    this.showStatsHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: showStatsHeader ? itemCount + 1 : itemCount,
        separatorBuilder: (context, index) =>
            SizedBox(height: (showStatsHeader && index == 0) ? 16 : 10),
        itemBuilder: (context, index) {
          if (showStatsHeader && index == 0) {
            return const LedgerStatsShimmer();
          }
          return const LedgerCardShimmer();
        },
      ),
    );
  }
}

/// Скелетон панели «Советы ИИ».
class LedgerAdviceShimmer extends StatelessWidget {
  const LedgerAdviceShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LedgerCard(
      borderColor: colors.border,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 22, height: 22, borderRadius: 6),
              SizedBox(width: 8),
              ShimmerBox(width: 120, height: 15, borderRadius: 4),
              Spacer(),
              ShimmerBox(width: 20, height: 20, borderRadius: 4),
            ],
          ),
          SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: 240, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Точный скелетон обзора дашборда: советы, ключевые метрики (Hero + 3 плитки), продажи, курсы, график, сетка отчетов.
class DashboardOverviewShimmer extends StatelessWidget {
  const DashboardOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Advice Panel
            const LedgerAdviceShimmer(),
            const SizedBox(height: 16),

            // 2. Hero Cash Balance Card
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 100, height: 12, borderRadius: 4),
                        SizedBox(height: 8),
                        ShimmerBox(width: 180, height: 26, borderRadius: 6),
                        SizedBox(height: 6),
                        ShimmerBox(width: 130, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  ShimmerBox(width: 48, height: 48, borderRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Metric tiles: 2×2 + full-width
            Row(
              children: [
                Expanded(child: _buildMetricTileShimmer()),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricTileShimmer()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricTileShimmer()),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricTileShimmer()),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricTileShimmer(),
            const SizedBox(height: 24),

            // 5. Sales & Profit Card
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ShimmerBox(width: 20, height: 20, borderRadius: 4),
                          SizedBox(width: 8),
                          ShimmerBox(width: 140, height: 15, borderRadius: 4),
                        ],
                      ),
                      ShimmerBox(width: 60, height: 12, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 70, height: 11, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 95, height: 17, borderRadius: 4),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 70, height: 11, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 95, height: 17, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ShimmerBox(
                    width: double.infinity,
                    height: 6,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Currency Board Card
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ShimmerBox(width: 20, height: 20, borderRadius: 4),
                          SizedBox(width: 8),
                          ShimmerBox(width: 130, height: 15, borderRadius: 4),
                        ],
                      ),
                      ShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: ShimmerBox(height: 48, borderRadius: 8)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 48, borderRadius: 8)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 48, borderRadius: 8)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7. Financial Chart Card
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 150, height: 15, borderRadius: 4),
                      ShimmerBox(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 16),
                  ShimmerBox(
                    width: double.infinity,
                    height: 160,
                    borderRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 8. Reports Title + Reports Grid
            const Row(
              children: [
                ShimmerBox(width: 32, height: 32, borderRadius: 8),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 16, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 180, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: LedgerCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            ShimmerBox(width: 28, height: 28, borderRadius: 6),
                            SizedBox(width: 10),
                            Expanded(
                              child: ShimmerBox(height: 14, borderRadius: 4),
                            ),
                            SizedBox(width: 6),
                            ShimmerBox(width: 14, height: 14, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: LedgerCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            ShimmerBox(width: 28, height: 28, borderRadius: 6),
                            SizedBox(width: 10),
                            Expanded(
                              child: ShimmerBox(height: 14, borderRadius: 4),
                            ),
                            SizedBox(width: 6),
                            ShimmerBox(width: 14, height: 14, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  static Widget _buildMetricTileShimmer() {
    return const LedgerCard(
      padding: EdgeInsets.all(14),
      constraints: BoxConstraints(minHeight: 124),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 20, height: 20, borderRadius: 4),
          SizedBox(height: 12),
          ShimmerBox(width: 90, height: 12, borderRadius: 4),
          SizedBox(height: 8),
          ShimmerBox(width: 110, height: 18, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: 40, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Точный скелетон обзора кассы: Hero смены, статус, операция, POS, 2 колонки, сводка, 1С ККМ, 5 операций.
class CashOverviewShimmer extends StatelessWidget {
  const CashOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHeroCardShimmer(),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 10),
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 10),
            const LedgerHubTileShimmer(),
            const SizedBox(height: 10),
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 10),
            const LedgerFeedHeaderShimmer(titleWidth: 100),
            const SizedBox(height: 6),
            ...List.generate(5, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: LedgerFeedRowShimmer(showChip: false),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон обзора кадров: Hero ФОТ, внимание, найм, 8 хаб-карточек 2×4, сотрудники.
class HrOverviewShimmer extends StatelessWidget {
  const HrOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 14),
            const LedgerHubGridShimmer(count: 8, gap: 12),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(circularLeading: true),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон CRM: Hero LTV, риски, клиент+сделка, 6 хаб-карточек, сделки.
class CrmOverviewShimmer extends StatelessWidget {
  const CrmOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 130, height: 13, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(width: 170, height: 26, borderRadius: 6),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      SizedBox(width: 12),
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 4),
                      ShimmerBox(width: 90, height: 13, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 16),
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 14),
            const LedgerHubGridShimmer(count: 6),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 140),
            const SizedBox(height: 10),
            ...List.generate(5, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон фин. операций: Hero ликвидности, внимание, 2 действия, 2×2, балансы филиалов, банки.
class FinOpsOverviewShimmer extends StatelessWidget {
  const FinOpsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 4, gap: 12),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: ShimmerBox(width: 150, height: 16, borderRadius: 4),
            ),
            const SizedBox(height: 10),
            ...List.generate(2, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShimmerBox(
                          width: 120,
                          height: 14,
                          borderRadius: 4,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 80, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 60, height: 11, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон маркетинга: Hero бюджет, баннер AI Studio, создать кампанию, 2×2, кампании.
class MarketingOverviewShimmer extends StatelessWidget {
  const MarketingOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 12),
            const LedgerStudioBannerShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 4, gap: 12),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон стратегии: Hero радара, 6 хаб-карточек 2×3, карточка AI-сводки.
class StrategyOverviewShimmer extends StatelessWidget {
  const StrategyOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 24),
            const LedgerHubGridShimmer(count: 6, gap: 12),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),
            const LedgerTextBlockShimmer(),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон обзора задач: прогресс, внимание, личная+командная, 2×2, срочные.
class TasksOverviewShimmer extends StatelessWidget {
  const TasksOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 110, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 72, height: 20),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 90, height: 24, borderRadius: 6),
                      ShimmerBox(width: 48, height: 18, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 10),
                  ShimmerBox(
                    width: double.infinity,
                    height: 6,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 14),
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 140),
            const SizedBox(height: 10),
            ...List.generate(5, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 160, height: 14, borderRadius: 4),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                LedgerChipShimmer(width: 60, height: 18),
                                SizedBox(width: 8),
                                ShimmerBox(
                                  width: 80,
                                  height: 11,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ShimmerBox(width: 18, height: 18, borderRadius: 4),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон обзора склада: Hero статистика остатков, плашка внимания, быстрые кнопки, 2х2 сетка разделов, недавние движения.
class WarehouseOverviewShimmer extends StatelessWidget {
  const WarehouseOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Stats Hero Card
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 12, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 110, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Attention Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 16),

            // 3. Quick Action Buttons Row
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 14),

            // 4. Section Grid Hub (2x2)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 20),

            // 5. Recent Movements Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            ...List.generate(5, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Скелетон инбокса: счётчик непрочитанных и карточки с точкой.
class InboxOverviewShimmer extends StatelessWidget {
  const InboxOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const ShimmerBox(width: 140, height: 13, borderRadius: 4),
          const SizedBox(height: 12),
          ...List.generate(6, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: ShimmerBox(width: 8, height: 8, borderRadius: 999),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 180, height: 15, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(
                            width: double.infinity,
                            height: 12,
                            borderRadius: 4,
                          ),
                          SizedBox(height: 6),
                          ShimmerBox(width: 110, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон уведомлений: критичные и календарь с футером, ИИ — без него.
class NotificationsOverviewShimmer extends StatelessWidget {
  const NotificationsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          _sectionHeader(180),
          const SizedBox(height: 10),
          _card(showFooter: true),
          _card(showFooter: true),
          const SizedBox(height: 8),
          _sectionHeader(160),
          const SizedBox(height: 10),
          _card(showFooter: false),
          _card(showFooter: false),
          const SizedBox(height: 8),
          _sectionHeader(170),
          const SizedBox(height: 10),
          _card(showFooter: true),
          _card(showFooter: true),
        ],
      ),
    );
  }

  static Widget _sectionHeader(double titleWidth) {
    return Row(
      children: [
        const ShimmerBox(width: 18, height: 18, borderRadius: 4),
        const SizedBox(width: 8),
        ShimmerBox(width: titleWidth, height: 15, borderRadius: 4),
      ],
    );
  }

  static Widget _card({required bool showFooter}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LedgerCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(child: ShimmerBox(height: 15, borderRadius: 4)),
                SizedBox(width: 8),
                ShimmerBox(width: 36, height: 36, borderRadius: 8),
              ],
            ),
            const SizedBox(height: 6),
            const ShimmerBox(
              width: double.infinity,
              height: 12,
              borderRadius: 4,
            ),
            const SizedBox(height: 4),
            const ShimmerBox(width: 220, height: 12, borderRadius: 4),
            if (showFooter) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 80, height: 12, borderRadius: 4),
                  ShimmerBox(width: 50, height: 11, borderRadius: 4),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон Meta: webhook-карточка, чипы каналов, диалоги.
class MetaOverviewShimmer extends StatelessWidget {
  const MetaOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const LedgerWebhookCardShimmer(),
          const SizedBox(height: 12),
          const SizedBox(
            height: 36,
            child: Row(
              children: [
                LedgerChipShimmer(width: 72, height: 36),
                SizedBox(width: 8),
                LedgerChipShimmer(width: 88, height: 36),
                SizedBox(width: 8),
                LedgerChipShimmer(width: 96, height: 36),
                SizedBox(width: 8),
                LedgerChipShimmer(width: 90, height: 36),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(6, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 140, height: 15, borderRadius: 4),
                          SizedBox(height: 5),
                          ShimmerBox(width: 200, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 36, height: 10, borderRadius: 4),
                        SizedBox(height: 6),
                        LedgerChipShimmer(width: 44, height: 18),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Точный скелетон пользователей: Hero, неактивные, одно действие, 2 хаба, список.
class UsersOverviewShimmer extends StatelessWidget {
  const UsersOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 2, gap: 12),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(circularLeading: true),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон интеграций: подключенные сервисы и журнал синхронизации.
class IntegrationsOverviewShimmer extends StatelessWidget {
  const IntegrationsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const LedgerFeedHeaderShimmer(titleWidth: 170),
          const SizedBox(height: 10),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 130, height: 15, borderRadius: 4),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            ShimmerBox(width: 8, height: 8, borderRadius: 4),
                            SizedBox(width: 6),
                            ShimmerBox(width: 60, height: 11, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                    ShimmerBox(width: 80, height: 32, borderRadius: 8),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          const ShimmerBox(width: 170, height: 15, borderRadius: 4),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              ShimmerBox(width: 110, height: 36, borderRadius: 8),
              ShimmerBox(width: 100, height: 36, borderRadius: 8),
              ShimmerBox(width: 130, height: 36, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 16),
          const LedgerFeedHeaderShimmer(titleWidth: 160),
          const SizedBox(height: 10),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ShimmerBox(width: 32, height: 32, borderRadius: 8),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 120, height: 13, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 80, height: 10, borderRadius: 4),
                        ],
                      ),
                    ),
                    LedgerChipShimmer(width: 54, height: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Точный скелетон аудита: Hero, аномалии, 2 действия, 2+1 хабы, события.
class AuditOverviewShimmer extends StatelessWidget {
  const AuditOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 12),
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 3, gap: 12),
            const SizedBox(height: 20),

            // 5. Recent Security Activity Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Точный скелетон чек-листов: Hero с прогрессом, создать шаблон, 2+1 хабы, 3 прогона.
class ChecklistsOverviewShimmer extends StatelessWidget {
  const ChecklistsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(showProgress: true),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 3, gap: 12),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 160),
            const SizedBox(height: 10),
            ...List.generate(3, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBox(width: 150, height: 15, borderRadius: 4),
                          LedgerChipShimmer(width: 68, height: 20),
                        ],
                      ),
                      SizedBox(height: 8),
                      ShimmerBox(width: 120, height: 11, borderRadius: 4),
                      SizedBox(height: 12),
                      ShimmerBox(
                        width: double.infinity,
                        height: 6,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Скелетон филиалов: иконка 42, имя/код, статус, адрес, телефон.
class BranchesOverviewShimmer extends StatelessWidget {
  const BranchesOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 42, height: 42, borderRadius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ShimmerBox(
                                width: 120,
                                height: 15,
                                borderRadius: 4,
                              ),
                              SizedBox(width: 6),
                              ShimmerBox(
                                width: 40,
                                height: 16,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              ShimmerBox(
                                width: 13,
                                height: 13,
                                borderRadius: 4,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: ShimmerBox(height: 12, borderRadius: 4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 68, height: 20),
                  ],
                ),
                SizedBox(height: 10),
                Divider(height: 1),
                SizedBox(height: 8),
                Row(
                  children: [
                    ShimmerBox(width: 13, height: 13, borderRadius: 4),
                    SizedBox(width: 4),
                    ShimmerBox(width: 110, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Точный скелетон сети: баннер точки, период, прибыль, 2 метрики, карточки магазинов.
class NetworkOverviewShimmer extends StatelessWidget {
  const NetworkOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LedgerCard(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                ShimmerBox(width: 36, height: 36, borderRadius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 90, height: 12, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 140, height: 14.5, borderRadius: 4),
                    ],
                  ),
                ),
                ShimmerBox(width: 72, height: 28, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 38, borderRadius: 8)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 38, borderRadius: 8)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 38, borderRadius: 8)),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 120, height: 13, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 160, height: 24, borderRadius: 6),
                        ],
                      ),
                    ),
                    ShimmerBox(width: 44, height: 44, borderRadius: 10),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 56, borderRadius: 10)),
                    SizedBox(width: 10),
                    Expanded(child: ShimmerBox(height: 56, borderRadius: 10)),
                  ],
                ),
                SizedBox(height: 10),
                ShimmerBox(width: 140, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: ShimmerBox(width: 160, height: 16, borderRadius: 4),
          ),
          const SizedBox(height: 10),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerBox(width: 40, height: 40, borderRadius: 10),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                width: 140,
                                height: 15,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 4),
                              ShimmerBox(
                                width: 100,
                                height: 12,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        LedgerChipShimmer(width: 64, height: 20),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 110, height: 16, borderRadius: 4),
                        ShimmerBox(width: 90, height: 32, borderRadius: 8),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Точный скелетон юриста: Hero, добавить закон, 2×2 хабы, дедлайны.
class LegalOverviewShimmer extends StatelessWidget {
  const LegalOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LedgerHubStatsHeroShimmer(),
            const SizedBox(height: 12),
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 4, gap: 12),
            const SizedBox(height: 20),
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerFeedRowShimmer(),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Скелетон чата с AI Юристом: чипы-подсказки, пузыри чата и поле ввода.
class LegalChatShimmer extends StatelessWidget {
  const LegalChatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ShimmerBox(width: 130, height: 32, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 150, height: 32, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 110, height: 32, borderRadius: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: const [
                Align(
                  alignment: Alignment.centerRight,
                  child: ShimmerBox(width: 200, height: 42, borderRadius: 12),
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 76,
                    borderRadius: 12,
                  ),
                ),
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ShimmerBox(width: 170, height: 38, borderRadius: 12),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(child: ShimmerBox(height: 44, borderRadius: 8)),
                SizedBox(width: 8),
                ShimmerBox(width: 44, height: 44, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелетон отчётов: фильтр филиала/дат, сумма продаж, дневные карточки.
class ReportsOverviewShimmer extends StatelessWidget {
  const ReportsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              children: [
                ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 38, borderRadius: 8)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 38, borderRadius: 8)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 130, height: 15, borderRadius: 4),
                ShimmerBox(width: 85, height: 18, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: 150, height: 16, borderRadius: 4),
          const SizedBox(height: 10),
          ...List.generate(4, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(
                                width: 110,
                                height: 15,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 4),
                              ShimmerBox(
                                width: 80,
                                height: 11,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        LedgerChipShimmer(width: 68, height: 20),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 90, height: 12, borderRadius: 4),
                        ShimmerBox(width: 100, height: 17, borderRadius: 4),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        ShimmerBox(width: 110, height: 26, borderRadius: 8),
                        SizedBox(width: 8),
                        ShimmerBox(width: 120, height: 26, borderRadius: 8),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон кампаний маркетинга: название, канал, шеврон.
class MarketingCampaignsShimmer extends StatelessWidget {
  const MarketingCampaignsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 150, height: 15, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 90, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                LedgerChipShimmer(width: 64),
                SizedBox(width: 8),
                ShimmerBox(width: 16, height: 16, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Скелетон постов маркетинга: пилюли, текст, дата.
class MarketingPostsShimmer extends StatelessWidget {
  const MarketingPostsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LedgerChipShimmer(width: 68),
                    LedgerChipShimmer(width: 76),
                  ],
                ),
                SizedBox(height: 10),
                ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 210, height: 13, borderRadius: 4),
                SizedBox(height: 12),
                ShimmerBox(width: 110, height: 11, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Вариант скелетона вкладки дашборда — совпадает с живыми виджетами раздела.
enum DashboardShimmerKind {
  pnl,
  planFact,
  breakEven,
  abc,
  accounts,
  clients,
  ai,
  onec,
}

/// Скелетон вкладок дашборда (P&L, план-факт, ABC, счета, клиенты, ИИ, 1С).
class DashboardSectionShimmer extends StatelessWidget {
  final DashboardShimmerKind kind;
  const DashboardSectionShimmer({
    super.key,
    this.kind = DashboardShimmerKind.pnl,
  });

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: switch (kind) {
          DashboardShimmerKind.pnl => _pnl(),
          DashboardShimmerKind.planFact => _planFact(),
          DashboardShimmerKind.breakEven => _breakEven(),
          DashboardShimmerKind.abc => _abc(),
          DashboardShimmerKind.accounts => _accounts(),
          DashboardShimmerKind.clients => _clients(),
          DashboardShimmerKind.ai => _ai(),
          DashboardShimmerKind.onec => _onec(),
        },
      ),
    );
  }

  static List<Widget> _tableRows({int count = 6}) {
    return List.generate(count, (index) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: ShimmerBox(height: 13, borderRadius: 4)),
            SizedBox(width: 12),
            ShimmerBox(width: 68, height: 13, borderRadius: 4),
            SizedBox(width: 8),
            ShimmerBox(width: 38, height: 11, borderRadius: 4),
          ],
        ),
      );
    });
  }

  static List<Widget> _pnl() {
    return [
      const ShimmerBox(width: 90, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      LedgerCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(children: _tableRows()),
      ),
      const SizedBox(height: 16),
      const ShimmerBox(width: 110, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      LedgerCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(children: _tableRows(count: 4)),
      ),
    ];
  }

  static List<Widget> _planFact() {
    return [
      const Row(
        children: [
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
        ],
      ),
      const SizedBox(height: 12),
      const LedgerCard(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 140, height: 13, borderRadius: 4),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 80, height: 32, borderRadius: 6),
                ShimmerBox(width: 120, height: 13, borderRadius: 4),
              ],
            ),
            SizedBox(height: 12),
            ShimmerBox(width: double.infinity, height: 8, borderRadius: 4),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const ShimmerBox(width: 160, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      ...List.generate(4, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerFeedRowShimmer(),
        );
      }),
    ];
  }

  static List<Widget> _breakEven() {
    return [
      const Row(
        children: [
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
        ],
      ),
      const SizedBox(height: 12),
      const LedgerCard(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 150, height: 13, borderRadius: 4),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 90, height: 32, borderRadius: 6),
                ShimmerBox(width: 100, height: 13, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const LedgerHubGridShimmer(count: 2, gap: 8),
      const SizedBox(height: 16),
      ...List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerFeedRowShimmer(),
        );
      }),
    ];
  }

  static List<Widget> _abc() {
    return [
      const Row(
        children: [
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
        ],
      ),
      const SizedBox(height: 12),
      const Row(
        children: [
          Expanded(child: ShimmerBox(height: 36, borderRadius: 999)),
          SizedBox(width: 8),
          Expanded(child: ShimmerBox(height: 36, borderRadius: 999)),
        ],
      ),
      const SizedBox(height: 16),
      ...List.generate(5, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerFeedRowShimmer(),
        );
      }),
    ];
  }

  static List<Widget> _accounts() {
    return [
      const ShimmerBox(width: 140, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      ...List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 130, height: 14, borderRadius: 4),
                    ShimmerBox(width: 90, height: 14, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    ShimmerBox(width: 80, height: 12, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: 18, height: 18, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
      const LedgerCard(
        padding: EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerBox(width: 120, height: 13, borderRadius: 4),
            ShimmerBox(width: 90, height: 16, borderRadius: 4),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const ShimmerBox(width: 110, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      const LedgerCard(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 70, height: 13, borderRadius: 4),
                ShimmerBox(width: 80, height: 13, borderRadius: 4),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 70, height: 13, borderRadius: 4),
                ShimmerBox(width: 80, height: 13, borderRadius: 4),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerBox(width: 70, height: 13, borderRadius: 4),
                ShimmerBox(width: 80, height: 13, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  static List<Widget> _clients() {
    return [
      const ShimmerBox(width: 120, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      ...List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerFeedRowShimmer(showChip: false),
        );
      }),
      const SizedBox(height: 12),
      const ShimmerBox(width: 140, height: 15, borderRadius: 4),
      const SizedBox(height: 8),
      ...List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerFeedRowShimmer(showChip: false),
        );
      }),
    ];
  }

  static List<Widget> _ai() {
    return [
      const LedgerCard(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 22, height: 22, borderRadius: 4),
                SizedBox(width: 10),
                ShimmerBox(width: 160, height: 14, borderRadius: 4),
              ],
            ),
            SizedBox(height: 12),
            ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
            SizedBox(height: 6),
            ShimmerBox(width: 220, height: 13, borderRadius: 4),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const LedgerAdviceShimmer(),
      const SizedBox(height: 12),
      const LedgerAdviceShimmer(),
    ];
  }

  static List<Widget> _onec() {
    return [
      const Row(
        children: [
          Expanded(
            child: LedgerCard(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 70, height: 11, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 90, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: LedgerCard(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 70, height: 11, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 90, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: LedgerCard(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 70, height: 11, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 90, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ...List.generate(4, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerFeedRowShimmer(),
        );
      }),
    ];
  }
}

/// Скелетон экрана «Ещё» (профиль, настройки, модули).
class MoreOverviewShimmer extends StatelessWidget {
  const MoreOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                ShimmerBox(width: 48, height: 48, borderRadius: 999),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 17, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 100, height: 12, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 80, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: 160, height: 14, borderRadius: 4),
          const SizedBox(height: 8),
          // Biometrics card
          const LedgerCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ShimmerBox(width: 20, height: 20, borderRadius: 4),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(width: 120, height: 14, borderRadius: 4),
                ),
                ShimmerBox(width: 36, height: 20, borderRadius: 999),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Language selector
          const LedgerCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ShimmerBox(width: 20, height: 20, borderRadius: 4),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 60, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 80, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: 120, height: 14, borderRadius: 4),
          const SizedBox(height: 6),
          ...List.generate(3, (group) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (group > 0) ...[
                    const ShimmerBox(width: 100, height: 14, borderRadius: 4),
                    const SizedBox(height: 6),
                  ],
                  ...List.generate(2, (row) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: LedgerCard(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 50,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShimmerBox(
                                      width: 20,
                                      height: 20,
                                      borderRadius: 4,
                                    ),
                                    SizedBox(height: 8),
                                    ShimmerBox(
                                      width: 90,
                                      height: 13,
                                      borderRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: LedgerCard(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                height: 50,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShimmerBox(
                                      width: 20,
                                      height: 20,
                                      borderRadius: 4,
                                    ),
                                    SizedBox(height: 8),
                                    ShimmerBox(
                                      width: 80,
                                      height: 13,
                                      borderRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон бэкапов: подсказка и список файлов с аватаром и размером.
class BackupsOverviewShimmer extends StatelessWidget {
  const BackupsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: 220, height: 12, borderRadius: 4),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    ShimmerBox(width: 40, height: 40, borderRadius: 999),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 160, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 70, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон POS: поле скана, каталог, корзина, чипы оплаты.
class CashPosShimmer extends StatelessWidget {
  final bool catalogOnly;
  const CashPosShimmer({super.key, this.catalogOnly = false});

  @override
  Widget build(BuildContext context) {
    final catalog = [
      for (var i = 0; i < 4; i++)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: LedgerCard(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 110, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                ShimmerBox(width: 18, height: 18, borderRadius: 4),
              ],
            ),
          ),
        ),
    ];
    if (catalogOnly) {
      return LedgerShimmer(child: Column(children: catalog));
    }
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const ShimmerBox(width: double.infinity, height: 52, borderRadius: 8),
          const SizedBox(height: 12),
          ...catalog,
          const SizedBox(height: 8),
          const ShimmerBox(width: 80, height: 14, borderRadius: 4),
          const SizedBox(height: 8),
          const ShimmerBox(width: 160, height: 12, borderRadius: 4),
          const SizedBox(height: 12),
          const Row(
            children: [
              LedgerChipShimmer(width: 72, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 88, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 80, height: 32),
            ],
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Скелетон сверки 1С ККМ: период, итоги, смены.
class CashOnecShimmer extends StatelessWidget {
  final bool includePeriod;
  const CashOnecShimmer({super.key, this.includePeriod = true});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: Column(
        children: [
          if (includePeriod)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(child: ShimmerBox(height: 40, borderRadius: 8)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 40, borderRadius: 8)),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const LedgerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 180, height: 12, borderRadius: 4),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBox(width: 90, height: 12, borderRadius: 4),
                          ShimmerBox(width: 70, height: 12, borderRadius: 4),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBox(width: 90, height: 12, borderRadius: 4),
                          ShimmerBox(width: 70, height: 12, borderRadius: 4),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShimmerBox(width: 90, height: 12, borderRadius: 4),
                          ShimmerBox(width: 70, height: 12, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(3, (index) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LedgerFeedRowShimmer(),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелетон календаря задач: переключатель, сетка месяца.
class TasksCalendarShimmer extends StatelessWidget {
  const TasksCalendarShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ShimmerBox(height: 38, borderRadius: 10),
          ),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 140, height: 16, borderRadius: 4),
                    Row(
                      children: [
                        ShimmerBox(width: 32, height: 32, borderRadius: 8),
                        SizedBox(width: 8),
                        ShimmerBox(width: 32, height: 32, borderRadius: 8),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(6, (row) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: ShimmerBox(height: 44, borderRadius: 8),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелетон матрицы RBAC: подсказка, роли, легенда, строки модулей.
class UsersMatrixShimmer extends StatelessWidget {
  const UsersMatrixShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const LedgerCard(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                ShimmerBox(width: 20, height: 20, borderRadius: 4),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 32, borderRadius: 4)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const ShimmerBox(width: 80, height: 12, borderRadius: 4),
          const SizedBox(height: 8),
          const Row(
            children: [
              LedgerChipShimmer(width: 88, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 96, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 80, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 72, height: 32),
            ],
          ),
          const SizedBox(height: 12),
          const LedgerCard(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 100, height: 13, borderRadius: 4),
                SizedBox(height: 8),
                Row(
                  children: [
                    LedgerChipShimmer(width: 48, height: 22),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 48, height: 22),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 48, height: 22),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 48, height: 22),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(8, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LedgerCard(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 14, borderRadius: 4)),
                    SizedBox(width: 12),
                    ShimmerBox(width: 22, height: 22, borderRadius: 4),
                    SizedBox(width: 12),
                    ShimmerBox(width: 22, height: 22, borderRadius: 4),
                    SizedBox(width: 12),
                    ShimmerBox(width: 22, height: 22, borderRadius: 4),
                    SizedBox(width: 12),
                    ShimmerBox(width: 22, height: 22, borderRadius: 4),
                    SizedBox(width: 12),
                    ShimmerBox(width: 22, height: 22, borderRadius: 4),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон бренд-гайда: карточка описания и форма полей.
class MarketingBrandGuideShimmer extends StatelessWidget {
  const MarketingBrandGuideShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 160, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 72, borderRadius: 8),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 72, borderRadius: 8),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
                SizedBox(height: 16),
                ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Вкладка AI Studio для скелетона первой загрузки.
enum MarketingStudioShimmerTab { ideas, production, roi }

/// Скелетон AI Studio: квота, идеи / сценарий / ROI.
class MarketingAiStudioShimmer extends StatelessWidget {
  final MarketingStudioShimmerTab tab;
  final bool wrapList;
  const MarketingAiStudioShimmer({
    super.key,
    this.tab = MarketingStudioShimmerTab.ideas,
    this.wrapList = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = switch (tab) {
      MarketingStudioShimmerTab.ideas => _ideas(),
      MarketingStudioShimmerTab.production => _production(),
      MarketingStudioShimmerTab.roi => _roi(),
    };
    if (!wrapList) {
      return LedgerShimmer(child: Column(children: children));
    }
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: children,
      ),
    );
  }

  static List<Widget> _ideas() {
    return [
      ...List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LedgerChipShimmer(width: 72, height: 22),
                    Spacer(),
                    ShimmerBox(width: 88, height: 28, borderRadius: 8),
                  ],
                ),
                SizedBox(height: 8),
                ShimmerBox(width: 180, height: 14, borderRadius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ),
        );
      }),
    ];
  }

  static List<Widget> _production() {
    return [
      const LedgerTextBlockShimmer(),
      const SizedBox(height: 16),
      const LedgerCard(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 140, height: 14, borderRadius: 4),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ShimmerBox(height: 40, borderRadius: 8)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 40, borderRadius: 8)),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  static List<Widget> _roi() {
    return List.generate(4, (index) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: LedgerCard(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerBox(width: 120, height: 14, borderRadius: 4),
                  LedgerChipShimmer(width: 72, height: 20),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Полоска квоты над вкладками AI Studio.
class MarketingStudioQuotaShimmer extends StatelessWidget {
  const MarketingStudioQuotaShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ShimmerBox(width: 16, height: 16, borderRadius: 4),
            SizedBox(width: 8),
            Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
            SizedBox(width: 8),
            LedgerChipShimmer(width: 56, height: 20),
          ],
        ),
      ),
    );
  }
}

/// Скелетон сводки чек-листов: две метрики и карточки с прогрессом.
class ChecklistsSummaryShimmer extends StatelessWidget {
  const ChecklistsSummaryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        children: [
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    ShimmerBox(width: 40, height: 24, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBox(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
                ShimmerBox(width: 1, height: 40, borderRadius: 0),
                Column(
                  children: [
                    ShimmerBox(width: 40, height: 24, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBox(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 150, height: 15, borderRadius: 4),
                        LedgerChipShimmer(width: 56, height: 20),
                      ],
                    ),
                    SizedBox(height: 12),
                    ShimmerBox(
                      width: double.infinity,
                      height: 6,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон отчёта аудита: статус и две колонки метрик.
class AuditReportShimmer extends StatelessWidget {
  const AuditReportShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerShimmer(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: LedgerCard(
          padding: EdgeInsets.all(18),
          child: Column(
            children: [
              ShimmerBox(width: 48, height: 48, borderRadius: 12),
              SizedBox(height: 12),
              ShimmerBox(width: 180, height: 16, borderRadius: 4),
              SizedBox(height: 8),
              ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
              SizedBox(height: 4),
              ShimmerBox(width: 220, height: 12, borderRadius: 4),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      ShimmerBox(width: 40, height: 24, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                  ShimmerBox(width: 1, height: 40, borderRadius: 0),
                  Column(
                    children: [
                      ShimmerBox(width: 40, height: 24, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Скелетон воронки CRM: горизонтальные колонки этапов.
class CrmFunnelShimmer extends StatelessWidget {
  const CrmFunnelShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: List.generate(3, (index) {
          return const Padding(
            padding: EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 280,
              child: LedgerCard(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ShimmerBox(
                            width: 120,
                            height: 14,
                            borderRadius: 4,
                          ),
                        ),
                        LedgerChipShimmer(width: 28, height: 20),
                      ],
                    ),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 12, borderRadius: 4),
                    SizedBox(height: 12),
                    LedgerCard(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 160, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 110, height: 12, borderRadius: 4),
                          SizedBox(height: 8),
                          ShimmerBox(width: 90, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    LedgerCard(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 140, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 90, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Скелетон товаров склада: две метрики, поиск, карточки с иконкой 44.
class WarehouseProductsShimmer extends StatelessWidget {
  const WarehouseProductsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const LedgerStatsShimmer(),
          const SizedBox(height: 16),
          const ShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
          const SizedBox(height: 12),
          ...List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    ShimmerBox(width: 44, height: 44, borderRadius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 150, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 100, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 54, height: 14, borderRadius: 4),
                        SizedBox(height: 4),
                        LedgerChipShimmer(width: 48, height: 18),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон анализа склада: заголовок, кнопка, текстовый блок ИИ.
class WarehouseAnalysisShimmer extends StatelessWidget {
  const WarehouseAnalysisShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerShimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 8),
                      ShimmerBox(width: 160, height: 15, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 6),
                  ShimmerBox(width: 220, height: 12, borderRadius: 4),
                  SizedBox(height: 14),
                  ShimmerBox(
                    width: double.infinity,
                    height: 44,
                    borderRadius: 8,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            LedgerTextBlockShimmer(),
          ],
        ),
      ),
    );
  }
}

/// Скелетон «Мои задачи»: три секции с карточками.
class TasksMyShimmer extends StatelessWidget {
  const TasksMyShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          for (var section = 0; section < 3; section++) ...[
            const Row(
              children: [
                ShimmerBox(width: 16, height: 16, borderRadius: 4),
                SizedBox(width: 8),
                ShimmerBox(width: 140, height: 14, borderRadius: 4),
                Spacer(),
                LedgerChipShimmer(width: 28, height: 18),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(section == 2 ? 1 : 2, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 160, height: 14, borderRadius: 4),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                LedgerChipShimmer(width: 60, height: 18),
                                SizedBox(width: 8),
                                ShimmerBox(
                                  width: 80,
                                  height: 11,
                                  borderRadius: 4,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Скелетон аналитики задач: перегруз и критический путь.
class TasksAnalyticsShimmer extends StatelessWidget {
  const TasksAnalyticsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const Row(
            children: [
              ShimmerBox(width: 16, height: 16, borderRadius: 4),
              SizedBox(width: 8),
              ShimmerBox(width: 160, height: 13, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ShimmerBox(width: 24, height: 24, borderRadius: 999),
                    SizedBox(width: 10),
                    Expanded(child: ShimmerBox(height: 14, borderRadius: 4)),
                    SizedBox(width: 8),
                    ShimmerBox(width: 40, height: 14, borderRadius: 4),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Row(
            children: [
              ShimmerBox(width: 16, height: 16, borderRadius: 4),
              SizedBox(width: 8),
              ShimmerBox(width: 150, height: 13, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(2, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 180, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 120, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон прогонов чек-листов: карточки с прогрессом.
class ChecklistsRunsShimmer extends StatelessWidget {
  const ChecklistsRunsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        children: List.generate(4, (index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LedgerCard(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 150, height: 15, borderRadius: 4),
                      LedgerChipShimmer(width: 72, height: 20),
                    ],
                  ),
                  SizedBox(height: 12),
                  ShimmerBox(
                    width: double.infinity,
                    height: 6,
                    borderRadius: 4,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Скелетон смен кассы: строка кассы и чип статуса.
class CashShiftsShimmer extends StatelessWidget {
  const CashShiftsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: List.generate(5, (index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LedgerCard(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 130, height: 14, borderRadius: 4),
                        SizedBox(height: 4),
                        ShimmerBox(width: 160, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  LedgerChipShimmer(width: 72, height: 22),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Скелетон сводки касс: карточка продаж и регистры.
class CashSummaryShimmer extends StatelessWidget {
  const CashSummaryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 20, height: 20, borderRadius: 4),
                    SizedBox(width: 8),
                    ShimmerBox(width: 140, height: 15, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 70, height: 11, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 95, height: 17, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 70, height: 11, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 95, height: 17, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 6, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 120, height: 15, borderRadius: 4),
                        LedgerChipShimmer(width: 64, height: 20),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 80, height: 12, borderRadius: 4),
                        ShimmerBox(width: 70, height: 12, borderRadius: 4),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 80, height: 12, borderRadius: 4),
                        ShimmerBox(width: 70, height: 12, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон матриц стратегии: чипы SWOT/PESTEL/BCG и сетка 2×2.
class StrategyMatricesShimmer extends StatelessWidget {
  const StrategyMatricesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const LedgerShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [LedgerHubGridShimmer(count: 4, gap: 8)],
      ),
    );
  }
}

/// Скелетон шаблонов юриста: название, описание, кнопка.
class LegalTemplatesShimmer extends StatelessWidget {
  const LegalTemplatesShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160, height: 15, borderRadius: 4),
                  SizedBox(height: 8),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 4),
                  ShimmerBox(width: 200, height: 12, borderRadius: 4),
                  SizedBox(height: 12),
                  ShimmerBox(width: 120, height: 36, borderRadius: 8),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Скелетон CRM-клиентов: 2×2 метрики, поиск, чипы, карточки с аватаром.
class CrmClientsShimmer extends StatelessWidget {
  const CrmClientsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          const Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 90, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 54, height: 18, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: LedgerCard(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 80, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 90, height: 18, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 90, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 40, height: 18, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: LedgerCard(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 80, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 40, height: 18, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const ShimmerBox(
            width: double.infinity,
            height: 48,
            borderRadius: 10,
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              LedgerChipShimmer(width: 72, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 88, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 80, height: 32),
              SizedBox(width: 8),
              LedgerChipShimmer(width: 64, height: 32),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LedgerFeedRowShimmer(circularLeading: true),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон лояльности CRM: заголовок и сетка 2×2.
class CrmLoyaltyShimmer extends StatelessWidget {
  const CrmLoyaltyShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const ShimmerBox(width: 140, height: 16, borderRadius: 4),
          const SizedBox(height: 12),
          ...List.generate(2, (row) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: LedgerCard(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 72,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LedgerChipShimmer(width: 64, height: 22),
                            Spacer(),
                            ShimmerBox(width: 90, height: 12, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 70, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: LedgerCard(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 72,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LedgerChipShimmer(width: 64, height: 22),
                            Spacer(),
                            ShimmerBox(width: 90, height: 12, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 70, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон законов: поиск, чипы категорий, список.
class LegalLawsShimmer extends StatelessWidget {
  const LegalLawsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                ShimmerBox(width: double.infinity, height: 48, borderRadius: 8),
                SizedBox(height: 8),
                Row(
                  children: [
                    LedgerChipShimmer(width: 72, height: 32),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 80, height: 32),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 96, height: 32),
                    SizedBox(width: 8),
                    LedgerChipShimmer(width: 88, height: 32),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              children: List.generate(5, (index) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LedgerCard(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 180, height: 15, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(
                          width: double.infinity,
                          height: 12,
                          borderRadius: 4,
                        ),
                        SizedBox(height: 4),
                        ShimmerBox(width: 160, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелетон новостей стратегии: группы по источнику.
class StrategyNewsShimmer extends StatelessWidget {
  const StrategyNewsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var group = 0; group < 3; group++) ...[
            const ShimmerBox(width: 140, height: 15, borderRadius: 4),
            const SizedBox(height: 8),
            ...List.generate(3, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(12),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 13,
                    borderRadius: 4,
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Скелетон оргструктуры: дерево со сдвигом, аватар и статус.
class HrOrgShimmer extends StatelessWidget {
  const HrOrgShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    const indents = [0.0, 16.0, 16.0, 32.0, 32.0, 16.0];
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final indent in indents)
            Padding(
              padding: EdgeInsets.only(left: indent, bottom: 8),
              child: const LedgerCard(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ShimmerBox(width: 36, height: 36, borderRadius: 999),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 130, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 90, height: 12, borderRadius: 4),
                        ],
                      ),
                    ),
                    LedgerChipShimmer(width: 64, height: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Универсальный скелетон списка карточек с заголовком и подписью.
class LedgerNamedListShimmer extends StatelessWidget {
  final int itemCount;
  const LedgerNamedListShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 150, height: 15, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 210, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 85, height: 11, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}
