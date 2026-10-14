import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_routes.dart';
import '../livelihood_strings.dart';
import '../providers/livelihood_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/lv_colors.dart';
import '../widgets/lv_scaffold.dart';
import '../widgets/report_parts.dart';

/// Entry screen. It shows where he stands: no details yet (add them), or details saved (see the
/// report, change them, or delete them).
class LivelihoodHomeScreen extends ConsumerStatefulWidget {
  const LivelihoodHomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final hasDetails = profile?.hasDetails ?? false;
    final pending = ref.watch(syncPendingProvider);

    return LvScaffold(
      title: s.t('lv_card_title'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.agriculture_rounded,
                  size: 40,
                  color: AppColors.forestSage,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  s.t('lv_title'),
                  style: AppTypography.display.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  s.t('lv_home_intro'),
                  style: AppTypography.bodyLarge.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // where he stands
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.sunkenBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
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

          if (hasDetails) ...[
            _Primary(
              icon: Icons.assessment_rounded,
              text: s.t('lv_show_report'),
              onPressed: () =>
                  Navigator.of(context).pushNamed(LivelihoodRoutes.report),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Secondary(
              icon: Icons.edit_outlined,
              text: s.t('lv_edit_details'),
              onPressed: () =>
                  Navigator.of(context).pushNamed(LivelihoodRoutes.details),
            ),
            const SizedBox(height: AppSpacing.sm),
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
          ] else ...[
            _Primary(
              icon: Icons.edit_note_rounded,
              text: s.t('lv_add_details'),
              onPressed: () =>
                  Navigator.of(context).pushNamed(LivelihoodRoutes.details),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Secondary(
              icon: Icons.assessment_rounded,
              text: s.t('lv_show_report'),
              onPressed: () =>
                  Navigator.of(context).pushNamed(LivelihoodRoutes.report),
            ),
          ],
          const SuggestionFooter(),
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

class _Primary extends StatelessWidget {
  const _Primary({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        text,
        style: AppTypography.labelLarge.copyWith(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.saffron,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final IconData icon;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: c.textPrimary),
      label: Text(
        text,
        style: AppTypography.labelLarge.copyWith(
          color: c.textPrimary,
          fontSize: 16,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
