import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/error_mapping.dart';
import '../livelihood_routes.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';
import '../providers/livelihood_providers.dart';
import '../widgets/analysis_card.dart';
import '../widgets/idea_card.dart';
import '../widgets/lv_badges.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/report_parts.dart';
import '../widgets/resource_card.dart';
import '../widgets/trust_label.dart';

/// The personal livelihood report: one scrolling screen (docs/FRONTEND_PLAN.md §3).
/// Order for M0: header, where you are heading, resources, your own resources, ideas,
/// why not others, weather, notes, footer. (The PDF order returns once weather is real.)
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = LivelihoodStrings.of(context);
    final report = ref.watch(reportProvider);
    return LvScaffold(
      title: s.t('lv_title'),
      body: report.when(
        loading: () => _Loading(s.t('lv_loading')),
        error: (e, _) => _Failed(
          message: s.t(errorMessageKey(e)),
          retry: s.t('lv_retry'),
          onRetry: () => ref.invalidate(reportProvider),
        ),
        data: (r) =>
            _ReportBody(r.report, fromCache: r.fromCache, savedAt: r.savedAt),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.saffron),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            style: AppTypography.body.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.retry,
    required this.onRetry,
  });

  final String message;
  final String retry;
  final VoidCallback onRetry;

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
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retry),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.saffron,
                minimumSize: const Size(160, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody(this.report, {this.fromCache = false, this.savedAt});

  final Report report;

  /// True when this is the last report saved on the phone, because the server could not be reached.
  final bool fromCache;
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final radiusKm = LivelihoodStrings.km(report.header.radiusM);
    final shown = report.resources.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        if (fromCache) ...[
          _OfflineBanner(savedAt),
          const SizedBox(height: AppSpacing.md),
        ],
        _HeaderCard(report),

        // where he is heading: what he asked for, so it comes first
        SectionHeader(s.t('lv_sec_heading')),
        AnalysisCard(report.analysis),

        // resources within the radius
        SectionHeader(
          s.t('lv_sec_resources', {'radius_km': radiusKm}),
          actionText: report.resources.length > shown.length
              ? s.t('lv_open_resources')
              : null,
          onAction: () =>
              Navigator.of(context).pushNamed(LivelihoodRoutes.resources),
        ),
        CountPills(report.counts),
        const SizedBox(height: AppSpacing.md),
        if (report.resources.isEmpty)
          Text(
            s.t('lv_no_resources', {'radius_km': radiusKm}),
            style: AppTypography.body.copyWith(color: c.textSecondary),
          )
        else
          for (final r in shown) ...[
            ResourceCard(r),
            const SizedBox(height: AppSpacing.sm),
          ],

        // what he told us
        if (report.toldByYou.isNotEmpty) ...[
          SectionHeader(s.t('lv_sec_own')),
          _TheirOwn(report.toldByYou),
        ],

        // ideas
        SectionHeader(s.t('lv_sec_ideas')),
        if (report.ideas.isEmpty)
          Text(
            s.t('lv_no_ideas'),
            style: AppTypography.body.copyWith(color: c.textSecondary),
          )
        else
          ..._ideas(context, s),

        // why not the others
        if (report.removed.isNotEmpty) ...[
          SectionHeader(s.t('lv_sec_why_not')),
          _WhyNot(report.removed),
        ],

        // weather and past disasters: sample numbers, clearly labelled
        if (report.weather != null) ...[
          SectionHeader(s.t('lv_sec_weather')),
          WeatherBars(report.weather!),
          NoteLine(s.t('lv_disasters_none'), icon: Icons.history_rounded),
        ],

        // honest gaps
        if (report.analysis.notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          for (final n in report.analysis.notes) NoteLine(s.note(n)),
        ],

        const SuggestionFooter(),
      ],
    );
  }

  List<Widget> _ideas(BuildContext context, LivelihoodStrings s) {
    final c = context.colors;
    final out = <Widget>[];
    String? group;
    for (final idea in report.ideas) {
      // sub-headings only when the server split the list (after he added details)
      if (idea.group != group && idea.group != 'ranked') {
        group = idea.group;
        out.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              s.t(
                idea.group == 'build_on_your_work'
                    ? 'lv_sec_build_on'
                    : 'lv_sec_other',
              ),
              style: AppTypography.subtitle.copyWith(color: c.textSecondary),
            ),
          ),
        );
      }
      out
        ..add(IdeaCardView(idea))
        ..add(const SizedBox(height: AppSpacing.sm));
    }
    return out;
  }
}

/// "Showing your last saved report": a quiet line, not a blocking dialog (the host's rule).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner(this.savedAt);

  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final when = savedAt?.toLocal();
    final date = when == null
        ? ''
        : ' (${when.day.toString().padLeft(2, '0')}-${when.month.toString().padLeft(2, '0')}-${when.year})';
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.sunkenBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: c.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${s.t('lv_showing_saved')}$date',
                style: AppTypography.body.copyWith(color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard(this.report);

  final Report report;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final h = report.header;
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
          Text(
            s.t('lv_report_for', {'name': h.name}),
            style: AppTypography.display.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${h.village(s.lang)}  ·  ${s.t(h.level == 'plot' ? 'lv_from_plot' : 'lv_from_village')}',
                  style: AppTypography.body.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (report.isSampleData) const SampleChip(),
              TagChip(s.t('lv_to_verify'), icon: Icons.fact_check_outlined),
            ],
          ),
          if (report.isSampleData)
            NoteLine(s.t('lv_sample_note'), icon: Icons.science_outlined),
          const SizedBox(height: AppSpacing.sm),
          TrustLabelView(h.trust),
        ],
      ),
    );
  }
}

class _TheirOwn extends StatelessWidget {
  const _TheirOwn(this.items);

  final List<ToldByYou> items;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
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
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in items)
                TagChip(
                  t.kind == 'animal'
                      ? '${s.animal(t.code)} ${t.count ?? ''}'.trim()
                      : s.asset(t.code),
                  icon: t.kind == 'animal'
                      ? Icons.pets_rounded
                      : Icons.handyman_outlined,
                ),
            ],
          ),
          NoteLine(s.t('lv_told_by_you'), icon: Icons.person_outline_rounded),
        ],
      ),
    );
  }
}

class _WhyNot extends StatelessWidget {
  const _WhyNot(this.items);

  final List<RemovedIdea> items;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
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
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    r.gate == null
                        ? Icons.hourglass_bottom_rounded
                        : Icons.block_rounded,
                    size: 18,
                    color:
                        r.gate == null ? c.textSecondary : AppColors.alertRed,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name(s.lang),
                          style: AppTypography.subtitle.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          s.reason(r.reason),
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
        ],
      ),
    );
  }
}
