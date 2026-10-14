import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/error_mapping.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';
import '../providers/livelihood_providers.dart';
import '../widgets/lv_badges.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/resource_card.dart';

/// Every resource within the radius, nearest first, with a filter by label.
class ResourcesScreen extends ConsumerWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final report = ref.watch(reportProvider);
    final filter = ref.watch(resourceFilterProvider);

    return LvScaffold(
      title: report.maybeWhen(
        data: (r) => s.t('lv_sec_resources', {
          'radius_km': LivelihoodStrings.km(r.report.header.radiusM),
        }),
        orElse: () => s.t('lv_title'),
      ),
      body: report.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.saffron),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(s.t(errorMessageKey(e)), textAlign: TextAlign.center),
          ),
        ),
        data: (result) {
          final r = result.report;
          final items = filter == null
              ? r.resources
              : r.resources.where((x) => x.label == filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _FilterChip(
                    text: '${s.t('lv_all')} ${r.counts.total}',
                    selected: filter == null,
                    onTap: () =>
                        ref.read(resourceFilterProvider.notifier).state = null,
                  ),
                  for (final label in UsefulLabel.values)
                    _FilterChip(
                      text: '${s.labelText(label)} ${_count(r.counts, label)}',
                      selected: filter == label,
                      color: UsefulBadge.color(label),
                      onTap: () => ref
                          .read(resourceFilterProvider.notifier)
                          .state = label,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (items.isEmpty)
                Text(
                  s.t('lv_no_resources', {
                    'radius_km': LivelihoodStrings.km(r.header.radiusM),
                  }),
                  style: AppTypography.body.copyWith(color: c.textSecondary),
                )
              else
                for (final item in items) ...[
                  ResourceCard(item),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          );
        },
      ),
    );
  }

  static int _count(Counts c, UsefulLabel l) => switch (l) {
        UsefulLabel.useful => c.useful,
        UsefulLabel.partlyUseful => c.partlyUseful,
        UsefulLabel.notUseful => c.notUseful,
      };
}

/// A filter chip at the 48 dp touch size, with a check mark when selected (not colour alone).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = color ?? AppColors.forestSage;
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: selected ? accent.withValues(alpha: 0.18) : c.chipUnselectedBg,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? accent : c.chipUnselectedBorder,
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
                    text,
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
