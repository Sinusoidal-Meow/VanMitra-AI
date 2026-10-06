import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'animated_counter.dart';
import 'bouncing_card.dart';

enum StatTileType {
  claims,
  meetings,
  resolutions,
  members,
  custom,
}

/// Modernized KPI StatTile with:
/// - AnimatedCounter for smooth count-up from 0 → target
/// - BouncingCard tactile press feedback
/// - Subtle colored ambient glow shadow matching the icon color
/// - Enhanced gradient icon background
class StatTile extends StatelessWidget {
  final StatTileType type;
  final String label;
  final String value;
  final IconData icon;
  final Color? customIconColor;
  final Color? iconColor;
  final Color? customBackgroundColor;
  final bool isLoading;
  final VoidCallback? onTap;

  /// Whether to animate the counter from 0 on first build.
  final bool animateValue;

  /// Whether to show the forward chevron icon when [onTap] is provided.
  /// Defaults to false to maintain clean, clutter-free KPI card layouts.
  final bool showChevron;

  const StatTile({
    super.key,
    this.type = StatTileType.custom,
    required this.label,
    required this.value,
    required this.icon,
    this.customIconColor,
    this.iconColor,
    this.customBackgroundColor,
    this.isLoading = false,
    this.onTap,
    this.animateValue = true,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Color activeIconColor;
    Color iconBgColor;

    if (iconColor != null) {
      activeIconColor = iconColor!;
      iconBgColor = customBackgroundColor ?? iconColor!.withValues(alpha: 0.12);
    } else {
      switch (type) {
        case StatTileType.claims:
          activeIconColor = c.isDark ? AppColors.forestMist : AppColors.forestCanopy;
          iconBgColor = activeIconColor.withValues(alpha: c.isDark ? 0.2 : 0.1);
          break;
        case StatTileType.meetings:
          activeIconColor = AppColors.successGreen;
          iconBgColor = AppColors.successGreen.withValues(alpha: 0.12);
          break;
        case StatTileType.resolutions:
          activeIconColor = AppColors.saffron;
          iconBgColor = AppColors.saffron.withValues(alpha: 0.15);
          break;
        case StatTileType.members:
          activeIconColor = c.isDark ? const Color(0xFFC084FC) : AppColors.womenPurple;
          iconBgColor = activeIconColor.withValues(alpha: 0.15);
          break;
        case StatTileType.custom:
          activeIconColor = customIconColor ?? (c.isDark ? AppColors.forestMist : AppColors.forestCanopy);
          iconBgColor = customBackgroundColor ?? activeIconColor.withValues(alpha: 0.1);
          break;
      }
    }

    final displayValue = (value == '-' || (value.isEmpty && !isLoading)) ? '0' : value;
    final numericValue = int.tryParse(displayValue);

    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Primary subtle shadow
          BoxShadow(
            color: c.isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0x0F0F172A),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
          // Colored ambient glow — subtle tint shadow matching the icon color
          BoxShadow(
            color: activeIconColor.withValues(alpha: c.isDark ? 0.05 : 0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
        ],
        border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.6 : 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Enhanced gradient icon background
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconBgColor,
                      iconBgColor.withValues(alpha: iconBgColor.a * 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: activeIconColor, size: 20),
              ),
              if (showChevron && onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: c.textTertiary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            // Shimmer placeholder
            Container(
              height: 22,
              width: 44,
              decoration: BoxDecoration(
                color: c.sunkenBg,
                borderRadius: BorderRadius.circular(6),
              ),
            )
          else if (animateValue && numericValue != null)
            // Animated count-up
            AnimatedCounter(
              targetValue: numericValue,
              duration: const Duration(milliseconds: 1200),
              style: AppTypography.stat.copyWith(
                fontSize: 22,
                height: 1.1,
                color: c.statNumber,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayValue,
                style: AppTypography.stat.copyWith(
                  fontSize: 22,
                  height: 1.1,
                  color: c.statNumber,
                ),
                maxLines: 1,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return BouncingCard(
      onTap: onTap,
      child: cardContent,
    );
  }
}
