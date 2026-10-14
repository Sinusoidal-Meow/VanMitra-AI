import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../widgets/lv_scaffold.dart';

/// The wildlife policy (Module 4 PDF §12). Static text; linked from the report footer.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return LvScaffold(
      title: s.t('lv_policy_title'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Icon(Icons.pets_rounded, size: 40, color: AppColors.forestSage),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t('lv_policy_body'),
            style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t('lv_policy_check'),
            style: AppTypography.body.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
