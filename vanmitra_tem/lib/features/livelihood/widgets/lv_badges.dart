import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';
import 'lv_colors.dart';

/// A small status pill: an icon AND a word, so colour is never the only signal
/// (style guide: status colours carry meaning only; accessibility: not colour alone).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
    this.outlined = false,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: outlined ? foreground : background),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelMedium.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Useful / Partly useful / Not useful. Green, amber, red, each with its own icon and word.
class UsefulBadge extends StatelessWidget {
  const UsefulBadge(this.label, {super.key});

  final UsefulLabel label;

  static Color color(UsefulLabel l) => switch (l) {
        UsefulLabel.useful => AppColors.successGreen,
        UsefulLabel.partlyUseful => AppColors.warningAmber,
        UsefulLabel.notUseful => AppColors.alertRed,
      };

  static IconData icon(UsefulLabel l) => switch (l) {
        UsefulLabel.useful => Icons.check_circle_rounded,
        UsefulLabel.partlyUseful => Icons.timelapse_rounded,
        UsefulLabel.notUseful => Icons.remove_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final bg = color(label);
    // dark text on amber, white on green and red, so contrast holds in both themes
    final fg = label == UsefulLabel.partlyUseful
        ? AppColors.textPrimary
        : Colors.white;
    return StatusPill(
      icon: icon(label),
      text: s.labelText(label),
      background: bg,
      foreground: fg,
    );
  }
}

/// Good / Fair / Weak fit for an idea. Labels only, never a number (rule L5).
class FitBadge extends StatelessWidget {
  const FitBadge(this.fit, {super.key});

  final FitLabel fit;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final (icon, bg, fg) = switch (fit) {
      FitLabel.good => (
          Icons.thumb_up_alt_rounded,
          AppColors.successGreen,
          Colors.white,
        ),
      FitLabel.fair => (
          Icons.thumbs_up_down_rounded,
          AppColors.warningAmber,
          AppColors.textPrimary,
        ),
      FitLabel.weak => (
          Icons.thumb_down_alt_rounded,
          AppColors.alertRed,
          Colors.white,
        ),
    };
    return StatusPill(
      icon: icon,
      text: s.fitText(fit),
      background: bg,
      foreground: fg,
    );
  }
}

/// Wildlife risk on every idea. Wording is "check with", never "safe" (rule L4).
class WildlifeBadge extends StatelessWidget {
  const WildlifeBadge(this.risk, {super.key});

  final Wildlife risk;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final (icon, color) = switch (risk) {
      Wildlife.low => (Icons.pets_rounded, c.textSecondary),
      Wildlife.medium => (Icons.pets_rounded, AppColors.warningAmber),
      Wildlife.needsPermission => (Icons.gpp_maybe_rounded, AppColors.alertRed),
    };
    return StatusPill(
      icon: icon,
      text: s.wildlifeText(risk),
      background: color,
      foreground: risk == Wildlife.low ? c.textSecondary : color,
      outlined: true,
    );
  }
}

/// A neutral chip for tags such as "Community forest", "Told by you", "Sample".
class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.icon, this.emphasis = false});

  final String text;
  final IconData? icon;
  final bool emphasis; // saffron outline for things that must not be missed

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = emphasis ? context.lvEmphasis : c.textSecondary;
    return StatusPill(
      icon: icon ?? Icons.label_outline_rounded,
      text: text,
      background: color,
      foreground: color,
      outlined: true,
    );
  }
}

/// The visible "Sample" marker for any report built from synthetic data (rule L1).
class SampleChip extends StatelessWidget {
  const SampleChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    return TagChip(
      s.t('lv_sample'),
      icon: Icons.science_outlined,
      emphasis: true,
    );
  }
}
