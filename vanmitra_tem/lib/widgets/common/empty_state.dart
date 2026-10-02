import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'primary_button.dart';

/// Standardized Empty State component replacing ad-hoc dashes or blank views across all screens.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  const EmptyState({
    super.key,
    this.icon = Icons.folder_open_rounded,
    required this.title,
    this.description,
    this.ctaLabel,
    this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final iconColor = c.isDark ? AppColors.forestMist : AppColors.forestSage;
    final circleBg = c.isDark
        ? AppColors.forestMist.withValues(alpha: 0.15)
        : AppColors.forestCanopy.withValues(alpha: 0.08);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.title.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                style: AppTypography.body.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (ctaLabel != null && onCtaPressed != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: ctaLabel!,
                onPressed: onCtaPressed,
                isFullWidth: false,
                icon: Icons.add_circle_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
