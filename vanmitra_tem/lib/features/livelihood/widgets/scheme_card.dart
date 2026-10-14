import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/scheme.dart';
import '../providers/detail_providers.dart';
import 'lv_badges.dart';

/// One scheme from the register. It says what the scheme is, who runs it, who can apply AS THE
/// OFFICIAL PAGE SAYS, which papers are usually asked for, when a person last checked it, and
/// links to the official page. It never says "you qualify" and never shows an amount (rule L1).
class SchemeCard extends ConsumerWidget {
  const SchemeCard(this.scheme, {super.key, this.compact = false});

  final Scheme scheme;

  /// Inside an idea detail: just the name, what it is, and the link.
  final bool compact;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final s = LivelihoodStrings.of(context);
    final ok = await ref.read(urlOpenerProvider)(scheme.officialUrl!);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.t('sch.open_failed'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final lang = s.lang;
    final note = scheme.note(lang);

    return Semantics(
      container: true,
      label: scheme.name(lang),
      child: Container(
        width: double.infinity,
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
                Expanded(
                  child: Text(
                    scheme.name(lang),
                    style: AppTypography.title.copyWith(color: c.textPrimary),
                  ),
                ),
                if (scheme.isSample) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const SampleChip(),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.t('sch.runs', {'who': scheme.runs(lang)}),
              style: AppTypography.caption.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              scheme.what(lang),
              style: AppTypography.body.copyWith(color: c.textPrimary),
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.md),
              _Section(
                title: s.t('sch.who'),
                child: Text(
                  scheme.who(lang),
                  style: AppTypography.body.copyWith(color: c.textPrimary),
                ),
              ),
              if (scheme.documents(lang).isNotEmpty)
                _Section(
                  title: s.t('sch.documents'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final d in scheme.documents(lang))
                        Text(
                          '•  $d',
                          style:
                              AppTypography.body.copyWith(color: c.textPrimary),
                        ),
                    ],
                  ),
                ),
              if (scheme.helpTypes.isNotEmpty || scheme.audiences.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final h in scheme.helpTypes)
                        TagChip(s.t('sch.help.$h')),
                      for (final a in scheme.audiences)
                        TagChip(s.t('sch.aud.$a')),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                scheme.neverChecked
                    ? s.t('sch.never_checked')
                    : s.t('sch.last_checked', {'date': scheme.lastCheckedOn}),
                style: AppTypography.caption.copyWith(color: c.textSecondary),
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                note,
                style: AppTypography.caption.copyWith(
                  color: c.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (scheme.officialUrl != null)
              FilledButton.icon(
                onPressed: () => _open(context, ref),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(s.t('sch.open')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forestSage,
                  minimumSize: const Size(160, 48),
                ),
              )
            else
              Row(
                children: [
                  Icon(Icons.link_off_rounded,
                      size: 18, color: c.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.t('sch.no_page'),
                      style:
                          AppTypography.body.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.subtitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}
