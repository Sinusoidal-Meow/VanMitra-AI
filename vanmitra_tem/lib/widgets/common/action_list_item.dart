import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_radius.dart';
import 'bouncing_card.dart';

/// Modernized ActionListItem with:
/// - BouncingCard tactile press feedback
/// - Gradient icon background
/// - Subtle colored ambient shadow
/// - Clean chevron animation on hover/press
class ActionListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ActionListItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final defaultIconColor = c.isDark ? AppColors.forestMist : AppColors.forestCanopy;
    final rawIconColor = iconColor ?? defaultIconColor;
    final effIconColor = (c.isDark && rawIconColor == AppColors.forestCanopy)
        ? AppColors.forestMist
        : rawIconColor;
    final effIconBg = iconBackgroundColor ?? effIconColor.withValues(alpha: c.isDark ? 0.18 : 0.10);

    final cardContent = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: c.isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A0F172A),
            offset: const Offset(0, 1),
            blurRadius: 6,
          ),
          // Subtle colored ambient glow
          BoxShadow(
            color: effIconColor.withValues(alpha: c.isDark ? 0.04 : 0.05),
            offset: const Offset(0, 3),
            blurRadius: 12,
          ),
        ],
        border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.6 : 0.45)),
      ),
      child: Row(
        children: [
          // Enhanced gradient icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effIconBg,
                  effIconBg.withValues(alpha: effIconBg.a * 0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: effIconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTypography.subtitle.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: c.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing ??
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c.sunkenBg.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: c.textTertiary,
                ),
              ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: BouncingCard(
        onTap: onTap,
        child: cardContent,
      ),
    );
  }
}
