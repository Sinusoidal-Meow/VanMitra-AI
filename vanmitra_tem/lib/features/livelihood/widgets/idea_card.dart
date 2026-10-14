import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';
import 'lv_badges.dart';
import 'lv_colors.dart';

/// One ranked idea. Rank, name, fit label, one-line reason, wildlife risk, cost and season, and
/// every flag the server raised (Gram Sabha only, Forest Department first, not enough land).
class IdeaCardView extends StatelessWidget {
  const IdeaCardView(this.idea, {super.key});

  final IdeaCard idea;

  /// Flags that must be seen get a warning colour; the rest are quiet information.
  static const _loud = {
    'flag.ask_forest_dept',
    'flag.possible_flood_risk',
    'flag.needs_more_land',
  };

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;

    return Semantics(
      container: true,
      label: '${idea.rank}. ${idea.name(s.lang)}, ${s.fitText(idea.fit)}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.forestCanopy,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${idea.rank}',
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    idea.name(s.lang),
                    style: AppTypography.title.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [FitBadge(idea.fit), WildlifeBadge(idea.wildlifeRisk)],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.reason(idea.reason),
              style: AppTypography.body.copyWith(color: c.textPrimary),
            ),
            if (idea.flags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final flag in idea.flags)
                _FlagRow(text: s.reason(flag), loud: _loud.contains(flag.key)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _Meta(
                  Icons.payments_outlined,
                  s.t('lv_cost_${idea.costLevel}'),
                ),
                _Meta(
                  Icons.calendar_month_outlined,
                  s.t('lv_season_${idea.bestSeason}'),
                ),
              ],
            ),
            if (idea.draft) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.t('lv_draft_idea'),
                style: AppTypography.caption.copyWith(
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlagRow extends StatelessWidget {
  const _FlagRow({required this.text, required this.loud});

  final String text;
  final bool loud;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = loud ? context.lvEmphasis : c.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            loud ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: loud ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: AppTypography.caption.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
