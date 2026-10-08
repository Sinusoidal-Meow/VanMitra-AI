import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routes/app_router.dart';
import '../../features/case_hub/case_hub_api.dart';
import '../../features/case_hub/cases_list_screen.dart';
import '../../features/gram_sabha_records/ledger_check_screen.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/common/app_components.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../home/villager_dashboard/hero_nature_layers.dart';

/// Profile & Settings in the villager design: a green hero card with the nature layers,
/// cloud sync diagnostics, account documents (claims, resolution ledger), help and logout.
class ProfileScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;

  /// Opens the Claims tab when the profile is a tab of the home screen.
  final VoidCallback? onOpenClaims;

  const ProfileScreen({super.key, this.bottomNavigationBar, this.onOpenClaims});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSyncing = false;

  /// Send anything saved offline, then check that the server is reachable.
  Future<void> _handleManualSync() async {
    setState(() => _isSyncing = true);
    String message;
    var ok = true;
    try {
      await CloudSyncService().syncPendingItems();
      final online = await CaseHubApi().health().catchError((_) => false);
      message = online
          ? 'Synced. The VanMitra server is reachable.'
          : 'Offline items synced, but the VanMitra server could not be reached.';
      ok = online;
    } catch (e) {
      message = 'Sync encountered an issue: $e';
      ok = false;
    }
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? AppColors.successGreen : AppColors.alertRed,
      ));
    }
  }

  void _openMyClaims() {
    if (widget.onOpenClaims != null) {
      widget.onOpenClaims!();
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CasesListScreen()));
    }
  }

  void _openLedger() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LedgerCheckScreen()));

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final c = context.colors;

    return PortalFrameScaffold(
      breadcrumbs: const ['Dashboard', 'Profile & Settings'],
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          const Positioned(right: -30, bottom: 40, child: LeafCorner(size: 140, mirrored: true)),
          ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _ProfileHeroCard(
                name: user?.name ?? 'VanMitra User',
                role: (user?.role.displayNameEn ?? 'Citizen').toUpperCase(),
                place: user?.villageId ?? '',
                onEmblemTap: () => Navigator.pushNamed(context, AppRouter.fraRightsInfo),
              ),
              const SizedBox(height: 22),

              // Cloud sync & offline storage diagnostics
              const VmSectionTitle('Cloud Sync & Offline Storage Diagnostics'),
              VmCard(
                child: Stack(
                  children: [
                    const Positioned(left: -14, bottom: -8, child: LeafSprig(width: 40, height: 70, opacity: 0.25)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_sync_rounded,
                                color: c.isDark ? AppColors.forestMist : const Color(0xFF143526), size: 26),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Hive Local Queue State',
                                  style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                            ),
                            const SyncStatusChip(showLabel: true, isLight: false),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Text(
                            'VanMitra-AI buffers all attendance check-ins, resolutions, and FRA claim filings locally in encrypted Hive storage during field surveys before syncing to the cloud.',
                            style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: OrangePillButton(
                            label: _isSyncing ? 'Synchronizing…' : 'Trigger Immediate Cloud Sync',
                            icon: Icons.sync_rounded,
                            busy: _isSyncing,
                            expand: true,
                            onPressed: _handleManualSync,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Account preferences & documents
              const VmSectionTitle('Account Preferences & Documents'),
              _PrefTile(
                icon: Icons.folder_rounded,
                iconColor: const Color(0xFFFF8A00),
                iconBg: const Color(0xFFFFF3E3),
                title: 'My Documents & FRA Claims',
                subtitle: 'Inspect filed claims, survey evidence & approved titles',
                onTap: _openMyClaims,
              ),
              const SizedBox(height: 10),
              _PrefTile(
                icon: Icons.description_rounded,
                iconColor: const Color(0xFF1E3A8A),
                iconBg: const Color(0xFFE8F1FF),
                title: 'Resolution Ledger & Chain Integrity',
                subtitle: 'Track approval workflow and document verification status',
                onTap: _openLedger,
              ),
              const SizedBox(height: 10),
              _PrefTile(
                icon: Icons.support_agent_rounded,
                iconColor: AppColors.womenQuorum,
                iconBg: const Color(0xFFF3E5F5),
                title: 'Help & Legal Aid Support',
                subtitle: 'Connect with local FRA rights NGOs & Tribal Development Officers',
                onTap: () => Navigator.pushNamed(context, AppRouter.fraRightsInfo),
              ),
              const SizedBox(height: 26),
              SecondaryButton(
                label: 'Logout from VanMitra-AI',
                icon: Icons.logout_rounded,
                outlineColor: AppColors.alertRed,
                onPressed: () => _confirmLogout(context),
              ),
            ],
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
          'Are you sure you want to end your current session? Offline data stays on this phone.',
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
            child: Text('Logout',
                style: AppTypography.subtitle.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Dark green rounded card with the hero's nature layers behind the user's identity.
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.name, required this.role, required this.place, this.onEmblemTap});

  final String name;
  final String role;
  final String place;
  final VoidCallback? onEmblemTap;

  @override
  Widget build(BuildContext context) {
    final display = name.trim().isEmpty ? 'VanMitra User' : name.trim();
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x33143526), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF143526), Color(0xFF1E4D3A)],
                  ),
                ),
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, height: 60, child: HeroHills()),
            const Positioned(left: 0, right: 0, bottom: 34, height: 24, child: HeroTreeLine()),
            const Positioned(left: -20, top: 10, width: 60, height: 130, child: HeroLeaves()),
            const Positioned(right: -16, top: -10, width: 56, height: 110, child: HeroLeaves(mirrored: true)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFFF9A2E), Color(0xFFFF8A00)]),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF8A00).withValues(alpha: 0.45), blurRadius: 14)],
                    ),
                    child: Text(display.characters.first.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $display',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Text(role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Color(0xFFCFE7D6)),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(place,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFFCFE7D6), fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onEmblemTap,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: const Icon(Icons.spa_rounded, color: Color(0xFFCFE7D6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return VmCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: c.isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3)),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.isDark ? const Color(0xFF23382B) : const Color(0xFFF1F5F3),
            ),
            child: Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}
