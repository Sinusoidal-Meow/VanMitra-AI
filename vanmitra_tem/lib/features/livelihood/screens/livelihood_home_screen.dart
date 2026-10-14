import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_routes.dart';
import '../livelihood_strings.dart';
import '../providers/host_hooks.dart';
import '../providers/livelihood_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/lv_action_card.dart';
import '../widgets/lv_colors.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/report_parts.dart';

/// Entry screen. It shows where he stands: no details yet (add them), or details saved (see the
/// report, ask about it, change the details, or delete them). Inside the host it is a tab of the
/// bottom bar ([bottomNavigationBar]) with the host's hero behind the top.
class LivelihoodHomeScreen extends ConsumerStatefulWidget {
  const LivelihoodHomeScreen({super.key, this.bottomNavigationBar});

  final Widget? bottomNavigationBar;

  @override
  ConsumerState<LivelihoodHomeScreen> createState() =>
      _LivelihoodHomeScreenState();
}

class _LivelihoodHomeScreenState extends ConsumerState<LivelihoodHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load what is saved (this also sends anything that was waiting for a connection). The home
    // screen does NOT ask for a report: building one is the report screen's job.
    Future.microtask(() => ref.read(profileProvider.notifier).load());
  }

  void _open(String route) => Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final hasDetails = profile?.hasDetails ?? false;
    final pending = ref.watch(syncPendingProvider);
    final hero = ref.watch(hostHeroBuilderProvider);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // where he stands
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pending
                    ? Icons.sync_rounded
                    : hasDetails
                        ? Icons.check_circle_outline_rounded
                        : Icons.edit_note_rounded,
                color: pending
                    ? context.lvEmphasis
                    : hasDetails
                        ? AppColors.successGreen
                        : context.lvEmphasis,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s.t(
                    pending
                        ? 'lv_sync_pending'
                        : hasDetails
                            ? 'lv_details_saved'
                            : 'lv_no_details_yet',
                  ),
                  style: AppTypography.body.copyWith(color: c.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          s.t('lv_hub_section'),
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!hasDetails) ...[
          LvActionCard(
            icon: Icons.edit_note_rounded,
            title: s.t('lv_add_details'),
            subtitle: s.t('lv_hub_add_sub'),
            accent: AppColors.saffron,
            highlight: true,
            onTap: () => _open(LivelihoodRoutes.details),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        LvActionCard(
          icon: Icons.auto_awesome_rounded,
          title: s.t('lv_ask_ai'),
          subtitle: s.t('lv_hub_ask_sub'),
          accent: AppColors.saffron,
          highlight: hasDetails,
          onTap: () => _open(LivelihoodRoutes.ask),
        ),
        const SizedBox(height: AppSpacing.sm),
        LvActionCard(
          icon: Icons.assessment_rounded,
          title: s.t('lv_show_report'),
          subtitle: s.t('lv_hub_report_sub'),
          accent: const Color(0xFF2E705B),
          onTap: () => _open(LivelihoodRoutes.report),
        ),
        const SizedBox(height: AppSpacing.sm),
        LvActionCard(
          icon: Icons.place_rounded,
          title: s.t('lv_hub_resources'),
          subtitle: s.t('lv_hub_resources_sub'),
          accent: const Color(0xFF2F5FB3),
          onTap: () => _open(LivelihoodRoutes.resources),
        ),
        const SizedBox(height: AppSpacing.sm),
        LvActionCard(
          icon: Icons.account_balance_rounded,
          title: s.t('lv_hub_schemes'),
          subtitle: s.t('lv_hub_schemes_sub'),
          accent: const Color(0xFFF0B323),
          onTap: () => _open(LivelihoodRoutes.schemes),
        ),
        if (hasDetails) ...[
          const SizedBox(height: AppSpacing.sm),
          LvActionCard(
            icon: Icons.edit_outlined,
            title: s.t('lv_edit_details'),
            subtitle: s.t('lv_hub_edit_sub'),
            accent: const Color(0xFF2E705B),
            onTap: () => _open(LivelihoodRoutes.details),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        LvActionCard(
          icon: Icons.pets_rounded,
          title: s.t('lv_policy_title'),
          subtitle: s.t('lv_hub_policy_sub'),
          accent: const Color(0xFF7A5C99),
          onTap: () => _open(LivelihoodRoutes.policy),
        ),
        if (hasDetails)
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(s.t('lv_delete_answers')),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor:
                  c.isDark ? const Color(0xFFFF8A80) : AppColors.alertRed,
            ),
          ),
        const SuggestionFooter(),
        // room for the raised bottom navigation, so nothing is hidden behind it
        SizedBox(height: widget.bottomNavigationBar != null ? 96 : 0),
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: content,
    );

    return LvScaffold(
      title: s.t('lv_card_title'),
      bottomNavigationBar: widget.bottomNavigationBar,
      body: hero != null
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: hero(
                context,
                ref,
                badge: s.t('lv_tab'),
                child: padded,
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Text(
                    s.t('lv_home_intro'),
                    style: AppTypography.bodyLarge
                        .copyWith(color: c.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                padded,
              ],
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final s = LivelihoodStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('lv_delete_title')),
        content: Text(s.t('lv_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(s.t('lv_keep')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(s.t('lv_delete_confirm')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(profileProvider.notifier).delete();
      ref.invalidate(
        reportProvider,
      ); // a report made from his answers must not linger
      messenger.showSnackBar(SnackBar(content: Text(s.t('lv_deleted'))));
    }
  }
}
