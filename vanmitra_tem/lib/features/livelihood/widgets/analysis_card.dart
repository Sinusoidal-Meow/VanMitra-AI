import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';

/// "Where you are heading": the one bold block of the report. Deep forest green with a saffron
/// rule, white text in both themes. Built from facts by the server; this only displays it.
class AnalysisCard extends StatelessWidget {
  const AnalysisCard(this.analysis, {super.key});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forestCanopy, AppColors.forestSage],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 4, color: AppColors.saffron),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.reason(analysis.headline),
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
                if (analysis.strengths.isNotEmpty)
                  _Group(
                    s.t('lv_sec_strengths'),
                    Icons.check_circle_outline_rounded,
                    analysis.strengths,
                    s,
                  ),
                if (analysis.ownResources.isNotEmpty)
                  _Group(
                    s.t('lv_sec_own'),
                    Icons.inventory_2_outlined,
                    analysis.ownResources,
                    s,
                  ),
                if (analysis.constraints.isNotEmpty)
                  _Group(
                    s.t('lv_sec_constraints'),
                    Icons.warning_amber_rounded,
                    analysis.constraints,
                    s,
                    accent: AppColors.saffron,
                  ),
                if (analysis.nextSteps.isNotEmpty)
                  _Group(
                    s.t('lv_sec_next'),
                    Icons.arrow_circle_right_outlined,
                    analysis.nextSteps,
                    s,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.icon, this.items, this.s, {this.accent});

  final String title;
  final IconData icon;
  final List<Reason> items;
  final LivelihoodStrings s;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.forestMist;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.subtitle.copyWith(color: tint)),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: tint),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.reason(item),
                      style: AppTypography.body.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
