import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/error_mapping.dart';
import '../livelihood_strings.dart';
import '../models/scheme.dart';
import '../providers/detail_providers.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/scheme_card.dart';

/// The Schemes tab (Module 4 PDF §13): Government and NGO, filters for the kind of help and who it
/// is for, and a card per scheme that links to the official page. We never take an application.
class SchemesScreen extends ConsumerStatefulWidget {
  const SchemesScreen({super.key});

  @override
  ConsumerState<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends ConsumerState<SchemesScreen> {
  String? _help;
  String? _audience;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final filter = SchemeFilter(help: _help, audience: _audience);
    final result = ref.watch(schemesProvider(filter));
    // the filter choices come from the whole register, not from the current (filtered) result
    final all = ref.watch(schemesProvider(const SchemeFilter()));

    return DefaultTabController(
      length: 2,
      child: LvScaffold(
        title: s.t('sch.title'),
        bottom: TabBar(
          indicatorColor: AppColors.saffron,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: s.t('sch.tab_government')),
            Tab(text: s.t('sch.tab_ngo')),
          ],
        ),
        body: Column(
          children: [
            if (all.valueOrNull != null)
              _Filters(
                help: _help,
                audience: _audience,
                helpTypes: all.value!.helpTypes,
                audiences: all.value!.audiences,
                onHelp: (v) => setState(() => _help = v),
                onAudience: (v) => setState(() => _audience = v),
              ),
            Expanded(
              child: result.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.saffron),
                ),
                error: (e, _) => _Message(
                  icon: Icons.cloud_off_rounded,
                  text: s.t(errorMessageKey(e)),
                  action: s.t('lv_retry'),
                  onAction: () => ref.invalidate(schemesProvider(filter)),
                ),
                data: (r) => TabBarView(
                  children: [
                    _SchemeList(r, SchemeKind.government),
                    _SchemeList(r, SchemeKind.ngo),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemeList extends StatelessWidget {
  const _SchemeList(this.result, this.kind);

  final SchemesResult result;
  final SchemeKind kind;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final rows = result.ofKind(kind);
    if (rows.isEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        text: s.t(
            result.registerEmpty ? 'sch.empty_register' : 'sch.empty_filter'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        if (result.isSampleData) ...[
          Text(
            s.t('sch.sample_note'),
            style: AppTypography.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final r in rows) ...[
          SchemeCard(r),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          s.t('sch.disclaimer'),
          style: AppTypography.caption.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.help,
    required this.audience,
    required this.helpTypes,
    required this.audiences,
    required this.onHelp,
    required this.onAudience,
  });

  final String? help;
  final String? audience;
  final List<String> helpTypes;
  final List<String> audiences;
  final ValueChanged<String?> onHelp;
  final ValueChanged<String?> onAudience;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    Widget row(
      String label,
      List<String> codes,
      String prefix,
      String? selected,
      ValueChanged<String?> onSelect,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(color: c.textSecondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      text: s.t('sch.filter_all'),
                      selected: selected == null,
                      onTap: () => onSelect(null),
                    ),
                    for (final code in codes)
                      _FilterChip(
                        text: s.t('$prefix$code'),
                        selected: selected == code,
                        onTap: () => onSelect(selected == code ? null : code),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Column(
        children: [
          row(s.t('sch.filter_help'), helpTypes, 'sch.help.', help, onHelp),
          row(s.t('sch.filter_who'), audiences, 'sch.aud.', audience,
              onAudience),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.forestSage.withValues(alpha: 0.18)
                  : c.chipUnselectedBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? AppColors.forestSage : c.chipUnselectedBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              text,
              style: AppTypography.labelMedium.copyWith(
                color: c.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(color: c.textPrimary),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.saffron,
                  minimumSize: const Size(160, 56),
                ),
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
