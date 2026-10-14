import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// An icon for an animal or asset code. Every option also carries its name: icons never stand
/// alone (accessibility), they only help someone who reads little find the right row.
IconData iconForCode(String code) => switch (code) {
      'cow' || 'buffalo' || 'bullock' => Icons.pets_rounded,
      'goat_sheep' => Icons.cruelty_free_rounded,
      'poultry' => Icons.egg_alt_rounded,
      'well' || 'borewell' || 'farm_pond' => Icons.water_drop_outlined,
      'shed' => Icons.warehouse_outlined,
      'pump' => Icons.settings_input_component_outlined,
      'drip_kit' => Icons.grain_rounded,
      'bullock_cart' || 'vehicle' => Icons.local_shipping_outlined,
      'storage_room' => Icons.inventory_2_outlined,
      'fodder_land' => Icons.grass_rounded,
      _ => Icons.more_horiz_rounded,
    };

/// A heading above a group of options inside a step.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppTypography.subtitle.copyWith(color: c.textPrimary),
        ),
      ),
    );
  }
}

/// A card-sized row with a "−  3  +" stepper. Both buttons are 48 dp.
class CounterTile extends StatelessWidget {
  const CounterTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onChanged,
    this.max = 999,
  });

  final IconData icon;
  final String label;
  final int count;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: '$label, $count',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: count > 0
              ? AppColors.forestSage.withValues(alpha: 0.12)
              : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: count > 0 ? AppColors.forestSage : c.border,
            width: count > 0 ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: c.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
              ),
            ),
            _StepButton(
              icon: Icons.remove_rounded,
              tooltip: '−',
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(color: c.textPrimary),
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              tooltip: '+',
              onPressed: count < max ? () => onChanged(count + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }
}

/// A tick row for "what do you already have" and "what did you do before". The tick is a real
/// icon (not colour alone), and the whole row is the touch target (56 dp high).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      checked: selected,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: selected
              ? AppColors.forestSage.withValues(alpha: 0.12)
              : c.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: selected ? AppColors.forestSage : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: c.textSecondary),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: selected ? AppColors.forestSage : c.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice out of several (land type, money level): a pill at the 48 dp touch size with a
/// check mark when chosen. Tapping the chosen one again clears it, since every question is optional.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: selected
              ? AppColors.forestSage.withValues(alpha: 0.18)
              : c.chipUnselectedBg,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.forestSage : c.chipUnselectedBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_rounded, size: 18, color: c.textPrimary),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
