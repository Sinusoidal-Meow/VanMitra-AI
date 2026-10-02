import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routes/app_router.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/common/app_components.dart';
import '../../widgets/portal_frame_scaffold.dart';

/// Renovated Profile & Settings Screen — featuring Forest Canopy identity, SyncStatus diagnostics,
/// legal aid connections, offline queue synchronization, and secure session management.
class ProfileScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  const ProfileScreen({super.key, this.bottomNavigationBar});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSyncing = false;

  Future<void> _handleManualSync() async {
    setState(() => _isSyncing = true);
    try {
      final syncService = CloudSyncService();
      await syncService.syncPendingItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud sync completed successfully!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync encountered an issue: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    final userName = auth.currentUser?.name ?? 'VanMitra User';
    final userRole = auth.currentUser?.role.displayNameEn ?? 'CITIZEN';
    final village = auth.currentUser?.villageId ?? 'Ozhar Gram Panchayat';

    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'Profile & Settings'],
      bottomNavigationBar: widget.bottomNavigationBar,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Profile Greeting Hero
                GreetingHero(
                  userName: userName,
                  role: userRole,
                  villageName: village,
                ),
                const SizedBox(height: AppSpacing.xl),

                // 2. Offline Storage & Cloud Diagnostics Card
                Text(
                  'Cloud Sync & Offline Storage Diagnostics',
                  style: AppTypography.title.copyWith(color: context.colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  elevation: AppElevation.raised,
                  borderColor: AppColors.forestSage.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_sync_rounded,
                                color: context.colors.isDark ? AppColors.forestMist : AppColors.forestCanopy,
                                size: 24,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Hive Local Queue State',
                                style: AppTypography.subtitle.copyWith(
                                  color: context.colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SyncStatusChip(showLabel: true, isLight: false),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'VanMitra-AI buffers all attendance check-ins, resolutions, and FRA claim filings locally in encrypted Hive storage during field surveys before syncing to Cloud Firestore.',
                        style: AppTypography.caption.copyWith(color: context.colors.textSecondary, height: 1.3),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: _isSyncing ? 'Synchronizing with Firestore...' : 'Trigger Immediate Cloud Sync',
                        icon: Icons.sync_rounded,
                        isLoading: _isSyncing,
                        onPressed: _handleManualSync,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 3. User Preferences & Document Directory
                Text(
                  'Account Preferences & Documents',
                  style: AppTypography.title.copyWith(color: context.colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                ActionListItem(
                  icon: Icons.folder_open_rounded,
                  title: 'My Documents & FRA Claims',
                  subtitle: 'Inspect filed claims, survey evidence & approved titles',
                  iconColor: AppColors.saffron,
                  onTap: () => Navigator.pushNamed(context, AppRouter.myClaims),
                ),
                const SizedBox(height: AppSpacing.sm),
                ActionListItem(
                  icon: Icons.gavel_rounded,
                  title: 'Resolution Ledger & Chain Integrity',
                  subtitle: 'Verify immutable Gram Sabha resolution records',
                  iconColor: AppColors.govtBlue,
                  onTap: () => Navigator.pushNamed(context, AppRouter.resolutionLedger),
                ),
                const SizedBox(height: AppSpacing.sm),
                ActionListItem(
                  icon: Icons.support_agent_rounded,
                  title: 'Help & Legal Aid Support',
                  subtitle: 'Connect with local FRA rights NGOs & Tribal Development Officers',
                  iconColor: AppColors.womenQuorum,
                  onTap: () => Navigator.pushNamed(context, AppRouter.fraRightsInfo),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // 4. Secure Session Terminate Affordance
                SecondaryButton(
                  label: 'Logout from VanMitra-AI',
                  icon: Icons.logout_rounded,
                  outlineColor: AppColors.alertRed,
                  onPressed: () => _confirmLogout(context),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 5. Digital India Government Footer Badge
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 32, color: AppColors.forestMist),
                      const SizedBox(height: 4),
                      Text(
                        'DIGITAL INDIA • TRIBAL DEVELOPMENT DEPARTMENT',
                        style: AppTypography.caption.copyWith(
                          fontSize: 10,
                          color: context.colors.textTertiary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        backgroundColor: c.dialogBg,
        title: Text('Logout from Portal', style: AppTypography.title.copyWith(color: c.textPrimary)),
        content: Text(
          'Are you sure you want to securely end your current session? Offline Hive data will remain preserved.',
          style: AppTypography.body.copyWith(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.subtitle.copyWith(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              Navigator.pushNamedAndRemoveUntil(context, AppRouter.splash, (_) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text('Logout', style: AppTypography.subtitle.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
