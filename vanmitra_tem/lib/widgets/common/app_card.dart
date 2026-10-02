import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Unified card primitive replacing inconsistent stat cards, action rows, and dashboard tiles.
class AppCard extends StatelessWidget {
  final Widget child;
  final AppElevation elevation;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.elevation = AppElevation.raised,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Border? resolvedBorder = borderColor != null
        ? Border.all(color: borderColor!, width: 1.2)
        : (c.isDark
            ? (elevation == AppElevation.flat
                ? Border.all(color: c.border.withValues(alpha: 0.6), width: 1.0)
                : (elevation == AppElevation.raised
                    ? Border.all(color: c.border.withValues(alpha: 0.4), width: 1.0)
                    : null))
            : elevation.border);

    final List<BoxShadow>? resolvedShadow = c.isDark
        ? (elevation == AppElevation.flat
            ? null
            : (elevation == AppElevation.raised
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      offset: const Offset(0, 4),
                      blurRadius: 16,
                    ),
                  ]))
        : elevation.shadow;

    final cardContent = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: resolvedShadow,
        border: resolvedBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
