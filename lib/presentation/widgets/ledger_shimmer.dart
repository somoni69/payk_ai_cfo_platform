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

/// Скелетон навигационной сетки 2x2 для Hub-экранов.
class LedgerHubGridShimmer extends StatelessWidget {
  final int count;
  const LedgerHubGridShimmer({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    if (count == 3) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTile()),
              const SizedBox(width: 10),
              Expanded(child: _buildTile()),
            ],
          ),
          const SizedBox(height: 10),
          _buildTile(),
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTile()),
            const SizedBox(width: 10),
            Expanded(child: _buildTile()),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildTile()),
            const SizedBox(width: 10),
            Expanded(child: _buildTile()),
          ],
        ),
      ],
    );
  }

  static Widget _buildTile() {
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

            // 3. Row of 2 Metric Tiles (Net Profit, Expenses)
            Row(
              children: [
                Expanded(child: _buildMetricTileShimmer()),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricTileShimmer()),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Full-width Metric Tile (Revenue)
            const LedgerCard(
              padding: EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShimmerBox(width: 18, height: 18, borderRadius: 4),
                          SizedBox(width: 8),
                          ShimmerBox(width: 100, height: 12, borderRadius: 4),
                        ],
                      ),
                      SizedBox(height: 8),
                      ShimmerBox(width: 120, height: 18, borderRadius: 4),
                    ],
                  ),
                  ShimmerBox(width: 54, height: 18, borderRadius: 6),
                ],
              ),
            ),
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
            ...List.generate(3, (index) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 18, height: 18, borderRadius: 4),
              SizedBox(width: 8),
              ShimmerBox(width: 80, height: 12, borderRadius: 4),
            ],
          ),
          SizedBox(height: 10),
          ShimmerBox(width: 100, height: 18, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: 50, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Точный скелетон обзора кассы: Hero баланс смены, статус смены, кнопка быстрой операции, сетка 3 разделов, недавние операции.
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
            // 1. Shift & Cash Hero Balance Card
            const LedgerHeroCardShimmer(hasActionButton: true),
            const SizedBox(height: 12),

            // 2. Attention Card (Active Shift status)
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 10),

            // 3. Quick Action Button (Full-width)
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 10),

            // 4. Navigation Grid (3 Section Cards)
            const LedgerHubGridShimmer(count: 3),
            const SizedBox(height: 10),

            // 5. Recent Activity Header
            const LedgerFeedHeaderShimmer(titleWidth: 100),
            const SizedBox(height: 10),

            // 6. Recent Operations List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 120, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 90, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 76, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 50, height: 10, borderRadius: 4),
                        ],
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

/// Точный скелетон обзора кадров: Hero ФОТ и KPI, плашка внимания, быстрое действие, 6 хаб-карточек, список сотрудников.
class HrOverviewShimmer extends StatelessWidget {
  const HrOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Total Payroll & Staff Metrics
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
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
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention & Risks Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Button (Full-width)
            const LedgerQuickActionsShimmer(count: 1),
            const SizedBox(height: 14),

            // 4. Main Navigation Grid (6 Hub Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Staff Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Staff List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 40, height: 40, borderRadius: 999),
                      SizedBox(width: 12),
                      Expanded(
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
                          ShimmerBox(width: 70, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 54, height: 18),
                        ],
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

/// Точный скелетон CRM: Hero сводка клиентов и воронки, плашка рисков оттока, 2 быстрых действия, 6 хаб-карточек, недавние сделки.
class CrmOverviewShimmer extends StatelessWidget {
  const CrmOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: CRM Stats & Funnel
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 130, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 70, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 170, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 100, height: 13, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 90, height: 13, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Attention & Churn Risks Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 16),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 14),

            // 4. Section Grid Hub (6 Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 10),
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Deals Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 140),
            const SizedBox(height: 10),

            // 6. Recent Deals List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 140, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 100, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 76, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 58, height: 18),
                        ],
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

/// Точный скелетон фин. операций: Hero сводка счетов/касс, плашка контроля казначейства, 2 быстрых действия, 6 хаб-карточек, недавние проводки.
class FinOpsOverviewShimmer extends StatelessWidget {
  const FinOpsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Total Balance & Treasury Stats
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
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
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention & Treasury Control Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main Navigation Grid (6 Hub Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Activity Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Transactions List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
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
                          ShimmerBox(width: 76, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 56, height: 18),
                        ],
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

/// Точный скелетон маркетинга: Hero бюджет, плашка внимания, быстрые действия (AI Копирайтер + Кампания), 6 хаб-карточек, недавние кампании.
class MarketingOverviewShimmer extends StatelessWidget {
  const MarketingOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Marketing Budget & Active Campaigns
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
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
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main Navigation Grid (6 Hub Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Campaigns Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Campaigns List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 140, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 100, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 76, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 58, height: 18),
                        ],
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

/// Точный скелетон стратегии: Hero сводка сценариев, плашка внимания, быстрые действия (What-If + Маркетинг), 6 хаб-карточек, недавние сценарии.
class StrategyOverviewShimmer extends StatelessWidget {
  const StrategyOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Strategy Scenarios
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 110, height: 13, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 120, height: 13, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main Navigation Grid (6 Hub Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Strategy Scenarios Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Strategy Scenarios List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 150, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 110, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 60, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 50, height: 18),
                        ],
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

/// Точный скелетон обзора задач: Hero сводка, плашка внимания, быстрые действия, 2х2 хаб-сетка, список срочных задач.
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
            // 1. Tasks Summary Hero Card
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 110, height: 12, borderRadius: 4),
                        SizedBox(height: 8),
                        ShimmerBox(width: 140, height: 26, borderRadius: 6),
                        SizedBox(height: 8),
                        ShimmerBox(
                          width: double.infinity,
                          height: 6,
                          borderRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  ShimmerBox(width: 48, height: 48, borderRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Attention Card (Overdue / On Track)
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 14),

            // 4. Navigation Grid (2x2)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 20),

            // 5. Recent Activity Header
            const LedgerFeedHeaderShimmer(titleWidth: 140),
            const SizedBox(height: 10),

            // 6. Recent Tasks List items
            ...List.generate(4, (index) {
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

            // 6. Recent Movements List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 140, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 100, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 70, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 56, height: 18),
                        ],
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

/// Скелетон инбокса: счётчик и карточки с точкой непрочитанного.
/// Точный скелетон экрана уведомлений: секции критических аномалий, рекомендаций ИИ и правового календаря.
class InboxOverviewShimmer extends StatelessWidget {
  const InboxOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          // Section 1 Header
          const Row(
            children: [
              ShimmerBox(width: 18, height: 18, borderRadius: 4),
              SizedBox(width: 8),
              ShimmerBox(width: 180, height: 15, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(2, (index) {
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
                        ShimmerBox(width: 160, height: 15, borderRadius: 4),
                        ShimmerBox(width: 18, height: 18, borderRadius: 4),
                      ],
                    ),
                    SizedBox(height: 6),
                    ShimmerBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: 4,
                    ),
                    SizedBox(height: 4),
                    ShimmerBox(width: 220, height: 12, borderRadius: 4),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 80, height: 12, borderRadius: 4),
                        ShimmerBox(width: 50, height: 11, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Section 2 Header
          const Row(
            children: [
              ShimmerBox(width: 18, height: 18, borderRadius: 4),
              SizedBox(width: 8),
              ShimmerBox(width: 160, height: 15, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(2, (index) {
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
                        ShimmerBox(width: 170, height: 15, borderRadius: 4),
                        ShimmerBox(width: 18, height: 18, borderRadius: 4),
                      ],
                    ),
                    SizedBox(height: 6),
                    ShimmerBox(
                      width: double.infinity,
                      height: 12,
                      borderRadius: 4,
                    ),
                    SizedBox(height: 4),
                    ShimmerBox(width: 190, height: 12, borderRadius: 4),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 80, height: 12, borderRadius: 4),
                        ShimmerBox(width: 50, height: 11, borderRadius: 4),
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

/// Точный скелетон Meta: переключатель каналов и карточки диалогов.
class MetaOverviewShimmer extends StatelessWidget {
  const MetaOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
            ],
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

/// Точный скелетон пользователей: Hero сводка, плашка неактивных, 2 быстрых действия, 2 хаб-карточки, список пользователей.
class UsersOverviewShimmer extends StatelessWidget {
  const UsersOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Users Count & Status
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
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
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main Navigation Grid (2 Hub Cards)
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Users Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Users List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 40, height: 40, borderRadius: 999),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 130, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 110, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          LedgerChipShimmer(width: 60, height: 18),
                          SizedBox(height: 4),
                          ShimmerBox(width: 44, height: 10, borderRadius: 4),
                        ],
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

/// Точный скелетон аудита: Hero сводка логов, плашка аномалий, 2 быстрых действия, 2х2 хаб-сетка, недавние события безопасности.
class AuditOverviewShimmer extends StatelessWidget {
  const AuditOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Security Logs & Severity
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 120, height: 13, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 90, height: 13, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main 2x2 Navigation Grid (4 Hub Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 20),

            // 5. Recent Security Activity Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Audit Events List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 140, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 90, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          LedgerChipShimmer(width: 58, height: 18),
                          SizedBox(height: 4),
                          ShimmerBox(width: 44, height: 10, borderRadius: 4),
                        ],
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

/// Точный скелетон операционных чек-листов 1:1: карточка исполнения ФОТ/регламентов, баннер статуса смен, быстрые действия, 3 карточки навигации, недавние регламенты.
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
            // 1. Hero Card: Execution & Compliance
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 170, height: 14, borderRadius: 4),
                      LedgerChipShimmer(width: 56, height: 20),
                    ],
                  ),
                  SizedBox(height: 10),
                  ShimmerBox(width: 220, height: 20, borderRadius: 4),
                  SizedBox(height: 12),
                  ShimmerBox(
                    width: double.infinity,
                    height: 6,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 14),
                  ShimmerBox(width: 160, height: 13, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Attention / Shift Status Banner
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main Navigation Grid (3 Hub Cards)
            const LedgerHubGridShimmer(count: 3),
            const SizedBox(height: 16),

            // 5. Recent Checklist Runs Header
            const LedgerFeedHeaderShimmer(titleWidth: 160),
            const SizedBox(height: 10),

            // 6. Recent Checklist Runs Feed
            const LedgerCard(
              padding: EdgeInsets.all(16),
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
                  SizedBox(height: 10),
                  ShimmerBox(width: 100, height: 11, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Скелетон филиалов: название, статус, адрес, телефон.
class BranchesOverviewShimmer extends StatelessWidget {
  const BranchesOverviewShimmer({super.key});

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
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 150, height: 16, borderRadius: 4),
                    LedgerChipShimmer(width: 68),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerBox(width: 16, height: 16, borderRadius: 4),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 12, borderRadius: 4)),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    ShimmerBox(width: 16, height: 16, borderRadius: 4),
                    SizedBox(width: 8),
                    ShimmerBox(width: 120, height: 12, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 10),
                Divider(height: 1),
                SizedBox(height: 8),
                ShimmerBox(width: 100, height: 11, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Точный скелетон сети магазинов / точек: переключатель периода, Hero сводка чистой прибыли и маржи сети, карточки торговых точек.
class NetworkOverviewShimmer extends StatelessWidget {
  const NetworkOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Card: Period + Net Profit + 3 Sub-metrics
          const LedgerCard(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 32, borderRadius: 8)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 32, borderRadius: 8)),
                    SizedBox(width: 6),
                    Expanded(child: ShimmerBox(height: 32, borderRadius: 8)),
                  ],
                ),
                SizedBox(height: 16),
                ShimmerBox(width: 120, height: 13, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 190, height: 26, borderRadius: 6),
                SizedBox(height: 14),
                Divider(height: 1),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 60, height: 11, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 80, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 60, height: 11, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 80, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 50, height: 11, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 60, height: 15, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Section Header
          const LedgerFeedHeaderShimmer(titleWidth: 160),
          const SizedBox(height: 10),

          // 3. Store Cards List
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
                        ShimmerBox(width: 140, height: 16, borderRadius: 4),
                        LedgerChipShimmer(width: 64, height: 20),
                      ],
                    ),
                    SizedBox(height: 6),
                    ShimmerBox(width: 180, height: 12, borderRadius: 4),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 90, height: 11, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 110, height: 18, borderRadius: 4),
                          ],
                        ),
                        ShimmerBox(width: 90, height: 34, borderRadius: 8),
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

/// Точный скелетон юриста / правового центра: Hero дедлайны, плашка внимания, быстрые действия (ИИ Юрист + Закон), 6 хаб-карточек, недавние дедлайны.
class LegalOverviewShimmer extends StatelessWidget {
  const LegalOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Card: Legal Deadlines & Laws Stats
            const LedgerCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 140, height: 13, borderRadius: 4),
                      LedgerChipShimmer(width: 64, height: 20),
                    ],
                  ),
                  SizedBox(height: 8),
                  ShimmerBox(width: 180, height: 26, borderRadius: 6),
                  SizedBox(height: 12),
                  Divider(height: 1),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      ShimmerBox(width: 16, height: 16, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 110, height: 13, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(width: 110, height: 13, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention Card
            const LedgerAttentionCardShimmer(),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row (2 buttons)
            const LedgerQuickActionsShimmer(count: 2),
            const SizedBox(height: 12),

            // 4. Main Navigation Grid (6 Hub Cards)
            const LedgerHubGridShimmer(count: 4),
            const SizedBox(height: 12),
            const LedgerHubGridShimmer(count: 2),
            const SizedBox(height: 20),

            // 5. Recent Deadlines Feed Header
            const LedgerFeedHeaderShimmer(titleWidth: 150),
            const SizedBox(height: 10),

            // 6. Recent Deadlines List
            ...List.generate(4, (index) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ShimmerBox(width: 36, height: 36, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 150, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            ShimmerBox(width: 100, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ShimmerBox(width: 60, height: 14, borderRadius: 4),
                          SizedBox(height: 4),
                          LedgerChipShimmer(width: 50, height: 18),
                        ],
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

/// Скелетон отчётов: фильтр, сумма, список дневных отчётов.
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
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                ShimmerBox(width: double.infinity, height: 38, borderRadius: 8),
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
          const SizedBox(height: 14),
          const ShimmerBox(width: 150, height: 16, borderRadius: 4),
          const SizedBox(height: 10),
          ...List.generate(4, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 110, height: 15, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 80, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                    LedgerChipShimmer(width: 68),
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

/// Скелетон вкладок дашборда (P&L и подобные таблицы/списки).
class DashboardSectionShimmer extends StatelessWidget {
  const DashboardSectionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const ShimmerBox(width: 90, height: 15, borderRadius: 4),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                ...List.generate(5, (index) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ShimmerBox(height: 13, borderRadius: 4),
                        ),
                        SizedBox(width: 12),
                        ShimmerBox(width: 68, height: 13, borderRadius: 4),
                        SizedBox(width: 8),
                        ShimmerBox(width: 38, height: 11, borderRadius: 4),
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
          const SizedBox(height: 8),
          // Module tiles grid
          Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13, borderRadius: 4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13, borderRadius: 4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13, borderRadius: 4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: const [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13, borderRadius: 4)),
                    ],
                  ),
                ),
              ),
            ],
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
