import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';
import 'lv_badges.dart';
import 'lv_colors.dart';
import 'trust_label.dart';

/// One resource near the land. A status rail on the left, the distance on the right (the thing
/// he can act on), and in between: name, label, one-line reason and the trust label.
class ResourceCard extends StatelessWidget {
  const ResourceCard(this.resource, {super.key});

  final ResourceItem resource;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final rail = UsefulBadge.color(resource.label);
    final metres = resource.distanceM;
    final far = metres >= 1000;

    return Semantics(
      container: true,
      label:
          '${resource.name(s.lang)}, ${s.labelText(resource.label)}, ${LivelihoodStrings.distance(metres)}',
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: rail),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name(s.lang),
                        style: AppTypography.subtitle.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        s.kind(resource.kind),
                        style: AppTypography.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          UsefulBadge(resource.label),
                          if (resource.useOnlyThroughGramSabha)
                            TagChip(
                              s.t('lv_tag_inside_cfr'),
                              icon: Icons.forest_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        s.reason(resource.reason),
                        style: AppTypography.body.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      if (resource.useOnlyThroughGramSabha) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _Note(
                          Icons.groups_rounded,
                          s.t('lv_gram_sabha_only'),
                          context.lvEmphasis,
                        ),
                      ],
                      if (resource.unknownChecks.isNotEmpty &&
                          !resource.checkedOnGround) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _Note(
                          Icons.help_outline_rounded,
                          s.t('lv_not_checked'),
                          c.textSecondary,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      TrustLabelView(resource.trust),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      far ? (metres / 1000).toStringAsFixed(1) : '$metres',
                      style: AppTypography.stat.copyWith(color: c.statNumber),
                    ),
                    Text(
                      far ? 'km' : 'm',
                      style: AppTypography.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.labelMedium.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
