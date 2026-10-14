import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/error_mapping.dart';
import '../livelihood_routes.dart';
import '../livelihood_strings.dart';
import '../models/scheme.dart';
import '../providers/detail_providers.dart';
import '../widgets/lv_badges.dart';
import '../widgets/lv_colors.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/report_parts.dart';
import '../widgets/resource_card.dart';
import '../widgets/scheme_card.dart';

/// One idea in detail (Module 4 PDF §9): why it was suggested, what it needs and whether that is
/// near or his own, the checks that ran, the resources it would use, a weather note, warnings,
/// and the schemes that may relate. The server builds it from his own report, so it can never
/// disagree with the report. Open it with `arguments: <idea code>`.
class IdeaDetailScreen extends ConsumerWidget {
  const IdeaDetailScreen({super.key, this.code});

  /// The idea code. When null it is read from the route arguments.
  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LivelihoodStrings.of(context);
    final ideaCode =
        code ?? (ModalRoute.of(context)?.settings.arguments as String?);
    return LvScaffold(
      title: s.t('idea.title'),
      body: ideaCode == null
          ? _Failed(message: s.t('lv_err_generic'))
          : ref.watch(ideaDetailProvider(ideaCode)).when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.saffron),
                ),
                error: (e, _) => _Failed(
                  message: s.t(errorMessageKey(e)),
                  retry: s.t('lv_retry'),
                  onRetry: () => ref.invalidate(ideaDetailProvider(ideaCode)),
                ),
                data: (d) => _Body(d),
              ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, this.retry, this.onRetry});

  final String message;
  final String? retry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: c.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
            ),
            if (retry != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.saffron,
                  minimumSize: const Size(160, 56),
                ),
                child: Text(retry!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.d);

  final IdeaDetail d;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final card = d.card;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        // header: name, where it stands, labels
        Text(
          d.name(s.lang),
          style: AppTypography.headlineSmall.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (d.fit != null) FitBadge(d.fit!),
            WildlifeBadge(card.wildlifeRisk),
            TagChip(s.t('lv_cost_${card.costLevel}'),
                icon: Icons.payments_outlined),
            TagChip(s.t('lv_season_${card.bestSeason}'),
                icon: Icons.calendar_month_outlined),
            if (d.isSampleData) const SampleChip(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          d.rank != null
              ? s.t('idea.rank', {'rank': d.rank})
              : s.t(d.isRemoved
                  ? 'idea.status_removed'
                  : 'idea.status_held_back'),
          style: AppTypography.subtitle.copyWith(
            color: d.isRemoved ? context.lvEmphasis : c.textSecondary,
          ),
        ),

        SectionHeader(s.t('idea.why')),
        Text(
          s.reason(card.reason),
          style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
        ),

        if (d.needs.isNotEmpty) ...[
          SectionHeader(s.t('idea.needs')),
          _Panel(children: [for (final n in d.needs) _NeedRow(n)]),
        ],

        if (d.checks.isNotEmpty) ...[
          SectionHeader(s.t('idea.checks')),
          _Panel(children: [for (final k in d.checks) _CheckRow(k)]),
        ],

        if (d.weatherNote != null) ...[
          SectionHeader(s.t('idea.weather')),
          NoteLine(s.reason(d.weatherNote!), icon: Icons.wb_sunny_outlined),
        ],

        if (d.resources.isNotEmpty) ...[
          SectionHeader(s.t('idea.resources')),
          for (final r in d.resources) ...[
            ResourceCard(r),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],

        if (card.flags.isNotEmpty) ...[
          SectionHeader(s.t('idea.warnings')),
          _Panel(
            children: [
              for (final f in card.flags)
                _Line(
                  icon: Icons.warning_amber_rounded,
                  color: context.lvEmphasis,
                  text: s.reason(f),
                ),
            ],
          ),
        ],

        // schemes: only for an idea that is not removed by law
        if (!d.isRemoved) ...[
          SectionHeader(s.t('idea.schemes')),
          if (d.schemes.isEmpty)
            Text(
              s.t('idea.schemes_none'),
              style: AppTypography.body.copyWith(color: c.textSecondary),
            )
          else ...[
            Text(
              s.t('idea.schemes_note'),
              style: AppTypography.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final sc in d.schemes) ...[
              SchemeCard(sc, compact: true),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () =>
                Navigator.of(context).pushNamed(LivelihoodRoutes.schemes),
            child: Text(s.t('idea.see_all_schemes')),
          ),
        ],

        if (card.draft) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            s.t('lv_draft_idea'),
            style: AppTypography.caption.copyWith(
              color: c.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SuggestionFooter(),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Found near you: Well", "You have: Pump", or "Not found: Well or Borewell".
class _NeedRow extends StatelessWidget {
  const _NeedRow(this.need);

  final NeedInfo need;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final met = need.metBy;
    final text = met == null
        ? s.t('idea.need_missing', {
            'what': need.options.map(s.needName).join(s.t('idea.or')),
          })
        : s.t(
            met.startsWith('asset:')
                ? 'idea.need_met_own'
                : 'idea.need_met_near',
            {'what': s.needName(met)},
          );
    return _Line(
      icon: met == null
          ? Icons.cancel_outlined
          : Icons.check_circle_outline_rounded,
      color: met == null ? context.lvEmphasis : AppColors.successGreen,
      text: text,
    );
  }
}

/// One check, as an icon, its name, a result word and the reason. Colour is never the only signal.
class _CheckRow extends StatelessWidget {
  const _CheckRow(this.check);

  final CheckInfo check;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final (IconData icon, Color color, String word) = switch (check.result) {
      CheckResult.passed => (
          Icons.check_circle_outline_rounded,
          AppColors.successGreen,
          s.t('idea.check.passed'),
        ),
      CheckResult.flagged => (
          Icons.warning_amber_rounded,
          context.lvEmphasis,
          s.t('idea.check.flagged'),
        ),
      CheckResult.notChecked => (
          Icons.help_outline_rounded,
          c.textSecondary,
          s.t('idea.check.not_checked'),
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.t('idea.check_name.${check.check}')}: $word',
                  style: AppTypography.subtitle.copyWith(color: c.textPrimary),
                ),
                Text(
                  s.reason(check.reason),
                  style: AppTypography.body.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
