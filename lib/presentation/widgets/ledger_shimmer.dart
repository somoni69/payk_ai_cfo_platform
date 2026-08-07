import 'package:flutter/material.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_card.dart';

/// Легковесный системный виджет эффекта Shimmer (мерцания загрузки)
/// в полном соответствии с дизайн-системой Ledger.
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
      duration: const Duration(milliseconds: 1400),
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
    final highlightColor = colors.surface;

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
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
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
        color: colors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Готовая карточка-скелетон для списков.
class LedgerCardShimmer extends StatelessWidget {
  final double height;
  const LedgerCardShimmer({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShimmerBox(width: 140, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerBox(width: 90, height: 10, borderRadius: 4),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(width: 70, height: 22, borderRadius: 12),
              SizedBox(height: 6),
              ShimmerBox(width: 80, height: 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Скелетон метрик (сводки) для верхней части экранов.
class LedgerStatsShimmer extends StatelessWidget {
  const LedgerStatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: LedgerCard(
            padding: const EdgeInsets.all(12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 80, height: 10, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 50, height: 24, borderRadius: 6),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: LedgerCard(
            padding: const EdgeInsets.all(12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 100, height: 10, borderRadius: 4),
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
            SizedBox(height: (showStatsHeader && index == 0) ? 16 : 12),
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

/// Точный скелетон для главного экрана Финансовой панели (Обзор).
class DashboardOverviewShimmer extends StatelessWidget {
  const DashboardOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Карточка "Рекомендация дня"
            LedgerCard(
              padding: const EdgeInsets.all(16),
              borderColor: Colors.amber.withValues(alpha: 0.3),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 150, height: 16, borderRadius: 4),
                  SizedBox(height: 12),
                  ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 6),
                  ShimmerBox(width: 240, height: 12, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Заголовок "ГЛАВНЫЕ ПОКАЗАТЕЛИ"
            const ShimmerBox(width: 170, height: 16, borderRadius: 4),
            const SizedBox(height: 12),

            // 3. Сетка 2x3 метрик (6 карточек)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                return LedgerCard(
                  padding: const EdgeInsets.all(14),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 100, height: 12, borderRadius: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 110, height: 20, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 50, height: 10, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 4. Заголовок "ДВИЖЕНИЕ ДЕНЕГ ЗА 30 ДНЕЙ"
            const ShimmerBox(width: 210, height: 16, borderRadius: 4),
            const SizedBox(height: 12),

            // 5. График
            LedgerCard(
              padding: const EdgeInsets.all(16),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerBox(width: 130, height: 14, borderRadius: 4),
                      ShimmerBox(width: 70, height: 14, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 20),
                  ShimmerBox(
                    width: double.infinity,
                    height: 150,
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

/// Точный скелетон для экрана "Касса" (Кассовые операции).
class CashOverviewShimmer extends StatelessWidget {
  const CashOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          // 1. Поисковая строка
          const ShimmerBox(width: double.infinity, height: 44, borderRadius: 12),
          const SizedBox(height: 10),

          // 2. Горизонтальная полоса чипсов-фильтров
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                ShimmerBox(width: 110, height: 34, borderRadius: 10),
                SizedBox(width: 8),
                ShimmerBox(width: 150, height: 34, borderRadius: 10),
                SizedBox(width: 8),
                ShimmerBox(width: 130, height: 34, borderRadius: 10),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 34, borderRadius: 10),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Список операций
          ...List.generate(7, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const ShimmerBox(width: 38, height: 38, borderRadius: 19),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 140, height: 14, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 90, height: 10, borderRadius: 4),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 85, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 65, height: 10, borderRadius: 4),
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

/// Точный скелетон для экрана "Сотрудники и кадры" (HR).
class HrOverviewShimmer extends StatelessWidget {
  const HrOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          // 1. Статистическая сводка (Штат и ФОТ)
          const LedgerStatsShimmer(),
          const SizedBox(height: 14),

          // 2. Поисковая строка
          const ShimmerBox(width: double.infinity, height: 42, borderRadius: 10),
          const SizedBox(height: 14),

          // 3. Карточки сотрудников
          ...List.generate(6, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const ShimmerBox(width: 42, height: 42, borderRadius: 21),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 130, height: 14, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 90, height: 10, borderRadius: 4),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 75, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
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
    );
  }
}

/// Точный скелетон для экрана "Лиды и сделки" (CRM).
class CrmOverviewShimmer extends StatelessWidget {
  const CrmOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          // 1. Статистика сделок и конверсии (3 карточки)
          const LedgerStatsShimmer(),
          const SizedBox(height: 14),

          // 2. Поиск и чипсы этапов воронки
          const ShimmerBox(width: double.infinity, height: 42, borderRadius: 10),
          const SizedBox(height: 10),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                ShimmerBox(width: 70, height: 32, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 100, height: 32, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 90, height: 32, borderRadius: 8),
                SizedBox(width: 8),
                ShimmerBox(width: 80, height: 32, borderRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Список сделок
          ...List.generate(6, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const ShimmerBox(width: 140, height: 16, borderRadius: 4),
                        const ShimmerBox(width: 80, height: 22, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const ShimmerBox(width: 100, height: 12, borderRadius: 4),
                        const Row(
                          children: [
                            ShimmerBox(width: 90, height: 16, borderRadius: 4),
                            SizedBox(width: 8),
                            ShimmerBox(width: 24, height: 24, borderRadius: 12),
                          ],
                        ),
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

/// Точный скелетон для экрана "Финансовые операции" (FinOps).
class FinOpsOverviewShimmer extends StatelessWidget {
  const FinOpsOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Статистическая сводка балансов
          const LedgerStatsShimmer(),
          const SizedBox(height: 16),

          // 2. Заголовок раздела
          const ShimmerBox(width: 180, height: 16, borderRadius: 4),
          const SizedBox(height: 12),

          // 3. Список банковских счетов
          ...List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const ShimmerBox(width: 36, height: 36, borderRadius: 8),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: 130, height: 14, borderRadius: 4),
                          SizedBox(height: 6),
                          ShimmerBox(width: 60, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShimmerBox(width: 100, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(width: 40, height: 10, borderRadius: 4),
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

/// Точный скелетон для экрана "Стратегия и AI-Маркетинг".
class StrategyOverviewShimmer extends StatelessWidget {
  const StrategyOverviewShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LedgerShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Карточка AI Рекомендации / Анализа
          LedgerCard(
            borderColor: Colors.amber.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShimmerBox(width: 24, height: 24, borderRadius: 12),
                    SizedBox(width: 8),
                    ShimmerBox(width: 140, height: 16, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Поле ввода сценария "Что если..."
          const ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
          const SizedBox(height: 20),

          // 3. Сетка 2x2 стратегических матриц (SWOT)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return LedgerCard(
                padding: const EdgeInsets.all(12),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 100, height: 14, borderRadius: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 120, height: 10, borderRadius: 4),
                        SizedBox(height: 4),
                        ShimmerBox(width: 80, height: 10, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
