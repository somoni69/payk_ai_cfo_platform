import 'package:flutter/material.dart';

import '../../core/theme/ledger_layout.dart';
import '../../core/theme/theme_extensions.dart';
import 'ledger_card.dart';

/// Plain icon mark — no glow, no glass, no halo.
class LedgerIconBadge extends StatelessWidget {
  const LedgerIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// Primary number on a screen: cash on hand, shift total, stock value.
class LedgerHero extends StatelessWidget {
  const LedgerHero({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.captionColor,
    this.trailing,
    this.footer,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? captionColor;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return LedgerCard(
      style: LedgerCardStyle.outlined,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: LedgerAnimatedValue(
                        value: value,
                        style: textStyles.h1Sans.copyWith(
                          fontSize: context.fontSize(30),
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        caption!,
                        style: textStyles.captionSans.copyWith(
                          color: captionColor ?? colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

/// Secondary KPI: icon, label, value, optional delta. Not a spreadsheet cell.
class LedgerMetricTile extends StatelessWidget {
  const LedgerMetricTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.delta,
    this.deltaColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? delta;
  final Color? deltaColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return SizedBox(
      width: double.infinity,
      child: LedgerCard(
        style: LedgerCardStyle.outlined,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          minHeight: context.layout.metricTileMinHeight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 12),
            Text(
              label,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: LedgerAnimatedValue(
                value: value,
                style: textStyles.h2Sans.copyWith(
                  fontSize: context.fontSize(18),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (delta != null) ...[
              const SizedBox(height: 4),
              Text(
                delta!,
                style: textStyles.smallSans.copyWith(
                  color: deltaColor ?? colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cross-fade + slight rise when a money/KPI string changes (currency switch).
class LedgerAnimatedValue extends StatelessWidget {
  const LedgerAnimatedValue({
    super.key,
    required this.value,
    required this.style,
    this.maxLines = 1,
  });

  final String value;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.hardEdge,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.22),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey(value),
        maxLines: maxLines,
        style: style,
      ),
    );
  }
}

/// Shortcut into a deeper report — used on the dashboard hub.
class LedgerReportTile extends StatelessWidget {
  const LedgerReportTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return LedgerCard(
      style: LedgerCardStyle.outlined,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.brand),
          const SizedBox(height: 12),
          Text(
            title,
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: textStyles.smallSans.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
