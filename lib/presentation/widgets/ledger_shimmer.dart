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

    return AnimatedBuilder(
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
  const LedgerHubGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
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

  Widget _buildTile() {
    return const LedgerCard(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 32, height: 32, borderRadius: 8),
              LedgerChipShimmer(width: 44, height: 18),
            ],
          ),
          SizedBox(height: 12),
          ShimmerBox(width: 90, height: 14, borderRadius: 4),
          SizedBox(height: 4),
          ShimmerBox(width: 110, height: 11, borderRadius: 4),
        ],
      ),
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

/// Точный скелетон обзора дашборда: советы, ключевые метрики, продажи, курсы, график.
class DashboardOverviewShimmer extends StatelessWidget {
  const DashboardOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LedgerAdviceShimmer(),
            const SizedBox(height: 16),
            const ShimmerBox(width: 170, height: 15, borderRadius: 4),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.45,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return const LedgerCard(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 90, height: 11, borderRadius: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 110, height: 18, borderRadius: 4),
                          SizedBox(height: 4),
                          ShimmerBox(width: 50, height: 10, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Sales & profit card skeleton
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ShimmerBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 8),
                      ShimmerBox(width: 140, height: 15, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
                      SizedBox(width: 6),
                      Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
                      SizedBox(width: 6),
                      Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Currency board card skeleton
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
                      ShimmerBox(width: 60, height: 11, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ShimmerBox(height: 52, borderRadius: 8)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 52, borderRadius: 8)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: ShimmerBox(height: 52, borderRadius: 8)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 52, borderRadius: 8)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Cash flow chart card skeleton
            const ShimmerBox(width: 210, height: 15, borderRadius: 4),
            const SizedBox(height: 10),
            const LedgerCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 140, height: 15, borderRadius: 4),
                  SizedBox(height: 16),
                  ShimmerBox(
                    width: double.infinity,
                    height: 160,
                    borderRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Скелетон кассы: поиск, фильтры и список операций.
class CashOverviewShimmer extends StatelessWidget {
  const CashOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          const ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
          const SizedBox(height: 10),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                ShimmerBox(width: 135, height: 38, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 160, height: 38, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 140, height: 38, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(6, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: LedgerCardShimmer(),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон кадров: список сотрудников с аватаром, должностью и зарплатой.
class HrOverviewShimmer extends StatelessWidget {
  const HrOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return const LedgerCard(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                ShimmerBox(width: 42, height: 42, borderRadius: 999),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 140, height: 15, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 170, height: 12, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 100, height: 10, borderRadius: 4),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LedgerChipShimmer(width: 68),
                    SizedBox(height: 8),
                    ShimmerBox(width: 76, height: 15, borderRadius: 4),
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

/// Скелетон CRM: три ячейки сводки, поиск, сегменты, карточки клиентов.
class CrmOverviewShimmer extends StatelessWidget {
  const CrmOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Expanded(child: _CrmStatCellShimmer()),
              SizedBox(width: 8),
              Expanded(child: _CrmStatCellShimmer()),
              SizedBox(width: 8),
              Expanded(child: _CrmStatCellShimmer()),
            ],
          ),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 44, borderRadius: 8),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 140, height: 15, borderRadius: 4),
                        LedgerChipShimmer(width: 68),
                      ],
                    ),
                    SizedBox(height: 8),
                    ShimmerBox(width: 110, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 15, borderRadius: 4),
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

class _CrmStatCellShimmer extends StatelessWidget {
  const _CrmStatCellShimmer();

  @override
  Widget build(BuildContext context) {
    return const LedgerCard(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 56, height: 10, borderRadius: 4),
          SizedBox(height: 6),
          ShimmerBox(width: 48, height: 16, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Скелетон фин. операций: заголовок и карточки счетов/переводов.
class FinOpsOverviewShimmer extends StatelessWidget {
  const FinOpsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const ShimmerBox(width: 160, height: 16, borderRadius: 4),
          const SizedBox(height: 10),
          ...List.generate(3, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    ShimmerBox(width: 38, height: 38, borderRadius: 8),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 130, height: 15, borderRadius: 4),
                          SizedBox(height: 5),
                          ShimmerBox(width: 90, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LedgerChipShimmer(width: 50, height: 20),
                        SizedBox(height: 5),
                        ShimmerBox(width: 80, height: 15, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const ShimmerBox(width: 180, height: 16, borderRadius: 4),
          const SizedBox(height: 10),
          ...List.generate(4, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCardShimmer(),
            );
          }),
        ],
      ),
    );
  }
}

/// Скелетон стратегии: сегменты, кнопка анализа, раскрываемые блоки.
class StrategyOverviewShimmer extends StatelessWidget {
  const StrategyOverviewShimmer({super.key});

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
            ],
          ),
          const SizedBox(height: 14),
          const ShimmerBox(
            width: double.infinity,
            height: 48,
            borderRadius: 12,
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: 170, height: 14, borderRadius: 4),
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
                          ShimmerBox(width: 160, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 110, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                    ShimmerBox(width: 20, height: 20, borderRadius: 4),
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

/// Скелетон задач: поиск + просрочено, фильтры проектов, карточки задач.
class TasksOverviewShimmer extends StatelessWidget {
  const TasksOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const Row(
            children: [
              Expanded(child: ShimmerBox(height: 44, borderRadius: 8)),
              SizedBox(width: 8),
              ShimmerBox(width: 110, height: 44, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 12),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                ShimmerBox(width: 100, height: 32, borderRadius: 999),
                SizedBox(width: 8),
                ShimmerBox(width: 120, height: 32, borderRadius: 999),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 32, borderRadius: 999),
                SizedBox(width: 8),
                ShimmerBox(width: 110, height: 32, borderRadius: 999),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const ShimmerBox(width: 150, height: 14, borderRadius: 4),
          const SizedBox(height: 8),
          ...List.generate(5, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerBox(width: 18, height: 18, borderRadius: 4),
                        SizedBox(width: 10),
                        Expanded(
                          child: ShimmerBox(
                            width: 160,
                            height: 15,
                            borderRadius: 4,
                          ),
                        ),
                        SizedBox(width: 8),
                        LedgerChipShimmer(width: 58, height: 20),
                      ],
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.only(left: 28),
                      child: Row(
                        children: [
                          ShimmerBox(width: 80, height: 11, borderRadius: 4),
                          SizedBox(width: 12),
                          ShimmerBox(width: 64, height: 11, borderRadius: 4),
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

/// Скелетон склада: две метрики и карточки товаров.
class WarehouseOverviewShimmer extends StatelessWidget {
  const WarehouseOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const LedgerStatsShimmer(),
          const SizedBox(height: 14),
          ...List.generate(6, (index) {
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
                          ShimmerBox(width: 150, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 90, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LedgerChipShimmer(width: 68),
                        SizedBox(height: 6),
                        ShimmerBox(width: 76, height: 14, borderRadius: 4),
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

/// Скелетон инбокса: счётчик и карточки с точкой непрочитанного.
class InboxOverviewShimmer extends StatelessWidget {
  const InboxOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const ShimmerBox(width: 130, height: 12, borderRadius: 4),
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
                      padding: EdgeInsets.only(top: 5),
                      child: ShimmerBox(width: 8, height: 8, borderRadius: 4),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 160, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(
                            width: double.infinity,
                            height: 12,
                            borderRadius: 4,
                          ),
                          SizedBox(height: 6),
                          ShimmerBox(width: 90, height: 10, borderRadius: 4),
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

/// Скелетон Meta: 4 канала и карточки диалогов.
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
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
              SizedBox(width: 6),
              Expanded(child: ShimmerBox(height: 34, borderRadius: 8)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(6, (index) {
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
                          ShimmerBox(width: 130, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 180, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 36, height: 10, borderRadius: 4),
                        SizedBox(height: 6),
                        LedgerChipShimmer(width: 22, height: 18),
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

/// Скелетон пользователей: поиск и карточки с ролью.
class UsersOverviewShimmer extends StatelessWidget {
  const UsersOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10, top: 4),
            child: ShimmerBox(
              width: double.infinity,
              height: 44,
              borderRadius: 8,
            ),
          ),
          ...List.generate(6, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    ShimmerBox(width: 38, height: 38, borderRadius: 999),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 140, height: 15, borderRadius: 4),
                          SizedBox(height: 5),
                          ShimmerBox(width: 110, height: 11, borderRadius: 4),
                        ],
                      ),
                    ),
                    LedgerChipShimmer(width: 76),
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

/// Скелетон интеграций: заголовок и карточки систем со статусом.
class IntegrationsOverviewShimmer extends StatelessWidget {
  const IntegrationsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const ShimmerBox(width: 170, height: 15, borderRadius: 4),
          const SizedBox(height: 10),
          ...List.generate(4, (index) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LedgerCard(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    ShimmerBox(width: 40, height: 40, borderRadius: 8),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 120, height: 15, borderRadius: 4),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              ShimmerBox(width: 6, height: 6, borderRadius: 4),
                              SizedBox(width: 6),
                              ShimmerBox(
                                width: 64,
                                height: 11,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ShimmerBox(width: 72, height: 32, borderRadius: 8),
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

/// Скелетон аудита: действие, время, автор, детали.
class AuditOverviewShimmer extends StatelessWidget {
  const AuditOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
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
                    ShimmerBox(width: 170, height: 15, borderRadius: 4),
                    ShimmerBox(width: 44, height: 11, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 6),
                ShimmerBox(width: 120, height: 11, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 11, borderRadius: 4),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Скелетон чек-листов: заголовок, прогресс и пункты.
class ChecklistsOverviewShimmer extends StatelessWidget {
  const ChecklistsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          return LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 150, height: 16, borderRadius: 4),
                    LedgerChipShimmer(width: 68),
                  ],
                ),
                const SizedBox(height: 6),
                const ShimmerBox(width: 160, height: 11, borderRadius: 4),
                const SizedBox(height: 12),
                const ShimmerBox(
                  width: double.infinity,
                  height: 6,
                  borderRadius: 4,
                ),
                const SizedBox(height: 12),
                ...List.generate(3, (i) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ShimmerBox(width: 18, height: 18, borderRadius: 4),
                        SizedBox(width: 10),
                        Expanded(
                          child: ShimmerBox(height: 13, borderRadius: 4),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
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

/// Скелетон сети магазинов / точек: сводка сети и карточки филиалов.
class NetworkOverviewShimmer extends StatelessWidget {
  const NetworkOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const BranchesOverviewShimmer();
  }
}

/// Скелетон юриста: чипы-подсказки, пузыри чата и поле ввода.
class LegalOverviewShimmer extends StatelessWidget {
  const LegalOverviewShimmer({super.key});

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
