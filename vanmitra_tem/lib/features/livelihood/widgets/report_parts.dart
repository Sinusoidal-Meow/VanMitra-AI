import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../livelihood_routes.dart';
import '../models/report.dart';
import 'lv_badges.dart';
import 'lv_colors.dart';

/// A section title with an optional action on the right (e.g. "See all resources").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionText, this.onAction});

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      // A Wrap, not a Row: with large text the action drops to its own line instead of overflowing.
      child: LayoutBuilder(
        builder: (context, box) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTypography.title.copyWith(color: c.sectionTitle),
                ),
              ),
            ),
            if (actionText != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth),
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(
                    actionText!,
                    style: AppTypography.labelLarge.copyWith(
                      color: context.lvEmphasis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Suggestion only. Check on the ground. The Gram Sabha decides." Never removed (PDF §17).
class SuggestionFooter extends StatelessWidget {
  const SuggestionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.sunkenBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: c.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s.t('lv_footer'),
                  style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(LivelihoodRoutes.policy),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              s.t('lv_policy_link'),
              style: AppTypography.labelLarge.copyWith(
                // blue link on light, soft green on dark, both readable on their surface
                color: c.isDark ? AppColors.forestMist : AppColors.govtBlue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three counts at the top of the resources section. Counts of items, not scores.
class CountPills extends StatelessWidget {
  const CountPills(this.counts, {super.key});

  final Counts counts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _Count(UsefulLabel.useful, counts.useful),
        _Count(UsefulLabel.partlyUseful, counts.partlyUseful),
        _Count(UsefulLabel.notUseful, counts.notUseful),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.count);

  final UsefulLabel label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return StatusPill(
      icon: UsefulBadge.icon(label),
      text: '$count  ${s.labelText(label)}',
      background: UsefulBadge.color(label),
      foreground: UsefulBadge.color(label) == AppColors.warningAmber
          ? c.textPrimary
          : UsefulBadge.color(label),
      outlined: true,
    );
  }
}

/// A plain notice line such as "Add your land area to check which ideas fit."
class NoteLine extends StatelessWidget {
  const NoteLine(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sample rainfall bars. Always labelled Sample while the numbers are synthetic (rule L1).
class WeatherBars extends StatelessWidget {
  const WeatherBars(this.weather, {super.key});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final maxRain = weather.months.fold<double>(
      1,
      (m, w) => w.rainMm > m ? w.rainMm : m,
    );
    return Container(
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
            children: [
              Expanded(
                child: Text(
                  s.t('lv_weather_rain'),
                  style: AppTypography.subtitle.copyWith(color: c.textPrimary),
                ),
              ),
              if (weather.isSample) const SampleChip(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in weather.months)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Semantics(
                        label: '${m.month}: ${m.rainMm.round()} mm',
                        child: Container(
                          height: 8 + 88 * (m.rainMm / maxRain),
                          decoration: BoxDecoration(
                            color: AppColors.forestSage,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final m in weather.months)
                Expanded(
                  child: Text(
                    '${m.month}',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            s.t('lv_weather_note'),
            style: AppTypography.caption.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
