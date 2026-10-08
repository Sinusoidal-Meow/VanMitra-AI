import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routes/app_router.dart';
import '../../models/notice.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claims_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/notices_provider.dart';
import '../../providers/village_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/common/app_components.dart';
import '../../widgets/common/vanmitra_background_watermark.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../features/case_hub/cases_list_screen.dart';
import '../gram_sabha/gram_sabha_dashboard.dart';
import '../profile/profile_screen.dart';
import 'boundary_map_screen.dart';

/// Renovated Admin Home Screen — authoritative governance dashboard built on Forest Canopy tokens,
/// Saffron navigation, StatTile diagnostic metrics, and seamless action linkages.
///
/// **Phase 2 Enhancements:**
/// - Full choreographed entry animation (header slide-in, staggered stats, action list cascade)
/// - AnimatedBottomNavBar with sliding pill + icon bounce
/// - BouncingCard tactile feedback on all interactive surfaces
/// - AnimatedCounter count-up on metric values
class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final navBar = AnimatedBottomNavBar(
      currentTab: AppTab.values[_currentTab],
      onTabSelected: (tab) => setState(() => _currentTab = tab.index),
    );

    return IndexedStack(
      index: _currentTab,
      children: [
        _AdminDashboard(bottomNavigationBar: navBar, onSwitchTab: (index) => setState(() => _currentTab = index)),
        CasesListScreen(bottomNavigationBar: navBar),
        _AdminProfileTab(bottomNavigationBar: navBar),
        _AdminGramSabhaTab(bottomNavigationBar: navBar),
        _AdminMapTab(bottomNavigationBar: navBar),
      ],
    );
  }
}

// ─── Animated Admin Dashboard ─────────────────────────────────────────────────

class _AdminDashboard extends ConsumerStatefulWidget {
  final Widget bottomNavigationBar;
  final ValueChanged<int>? onSwitchTab;

  const _AdminDashboard({required this.bottomNavigationBar, this.onSwitchTab});

  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard>
    with TickerProviderStateMixin {
  // ── Animation Controllers ──────────────────────────────────────────────────
  late final AnimationController _headerController;
  late final AnimationController _statsController;
  late final AnimationController _actionsController;

  // ── Header animations ─────────────────────────────────────────────────────
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerFade;

  // ── Stats stack entrance animations ───────────────────────────────────────
  late final Animation<double> _statFade;
  late final Animation<Offset> _statSlide;

  // ── Action list animations (6 staggered) ──────────────────────────────────
  static const int _actionCount = 6;
  late final List<Animation<double>> _actionFades;
  late final List<Animation<Offset>> _actionSlides;

  @override
  void initState() {
    super.initState();

    // ── 1. Header: Slide down from top + fade in ────────────────────────────
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    // ── 2. Stats Stack: Smooth interpolated entrance ────────────────────────
    _statsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _statFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsController, curve: Curves.easeOut),
    );
    _statSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _statsController, curve: Curves.easeOutCubic),
    );

    // ── 3. Action List: Staggered fade + slide-in from bottom ───────────────
    _actionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _actionFades = List.generate(_actionCount, (i) {
      final start = (i * 0.08).clamp(0.0, 0.6);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _actionsController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    _actionSlides = List.generate(_actionCount, (i) {
      final start = (i * 0.08).clamp(0.0, 0.6);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _actionsController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));
    });

    // ── Choreographed launch sequence ───────────────────────────────────────
    _startEntryAnimation();
  }

  Future<void> _startEntryAnimation() async {
    // Wait a frame for the widget tree to settle
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    _headerController.forward();

    // Stats start 200ms after header begins
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _statsController.forward();

    // Actions start 300ms after stats begin
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _actionsController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _statsController.dispose();
    _actionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final village = ref.watch(villageProvider);
    final resolutions = ref.watch(resolutionProvider);
    
    final villageId = village?.id ?? '';
    final claimsAsync = ref.watch(claimsStreamProvider(villageId));
    final meetingsAsync = ref.watch(meetingsStreamProvider(villageId));

    final totalClaims = claimsAsync.maybeWhen(
      data: (list) => list.length.toString(),
      orElse: () => '0',
    );
    
    final totalMeetings = meetingsAsync.maybeWhen(
      data: (list) => list.where((m) => m.status.name == 'completed').length.toString(),
      orElse: () => '0',
    );

    // Action items data
    final actions = _buildActions(context, ref, totalClaims);

    return PortalFrameScaffold(
      breadcrumbs: const [],
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          const DashboardCurveBackground(),
          const Positioned.fill(
            child: VanMitraBackgroundWatermark(),
          ),
          CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ═══════════════════════════════════════════════════════════════
                // 1. GOVERNANCE GREETING HERO — Slide in from top + Fade
                // ═══════════════════════════════════════════════════════════════
                AnimatedBuilder(
                  animation: _headerController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _headerSlide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: GreetingHero(
                          userName: auth.currentUser?.name ?? "Admin Officer",
                          role: "FRC Admin • Gram Sabha Secretary",
                          villageName: village?.nameMarathi ?? "ओझर ग्रा.पं.",
                          onProfileTap: () => widget.onSwitchTab?.call(AppTab.profile.index),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ═══════════════════════════════════════════════════════════════
                // 2. FOCUSED CARD STACK — Interactive Swipeable KPI Deck
                // ═══════════════════════════════════════════════════════════════
                AnimatedBuilder(
                  animation: _statsController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _statFade,
                      child: SlideTransition(
                        position: _statSlide,
                        child: child,
                      ),
                    );
                  },
                  child: StatisticCardStack(
                    items: [
                      StatisticCardItem(
                        value: totalClaims,
                        label: context.tr('total_claims'),
                        icon: Icons.description_rounded,
                        iconColor: AppColors.saffron,
                        subtitle: 'Adjudicate & monitor FRA claims',
                        onTap: () => widget.onSwitchTab?.call(AppTab.claims.index),
                      ),
                      StatisticCardItem(
                        value: totalMeetings,
                        label: context.tr('meetings'),
                        icon: Icons.groups_rounded,
                        iconColor: AppColors.successGreen,
                        subtitle: 'Scheduled & held Gram Sabhas',
                        onTap: () => widget.onSwitchTab?.call(AppTab.sabha.index),
                      ),
                      StatisticCardItem(
                        value: '${resolutions.length}',
                        label: context.tr('resolutions'),
                        icon: Icons.gavel_rounded,
                        iconColor: AppColors.govtBlue,
                        subtitle: 'Official CFR resolution ledger',
                        onTap: () => Navigator.pushNamed(context, AppRouter.resolutionLedger),
                      ),
                      StatisticCardItem(
                        value: '${village?.registeredAdultMembers ?? 500}',
                        label: context.tr('members'),
                        icon: Icons.people_alt_rounded,
                        iconColor: AppColors.forestSage,
                        subtitle: 'Adult Gram Sabha voters & quorum',
                        onTap: () => Navigator.pushNamed(context, AppRouter.attendanceManagement),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ═══════════════════════════════════════════════════════════════
                // 3. ADMIN GOVERNANCE OPERATIONS — Staggered cascade from bottom
                // ═══════════════════════════════════════════════════════════════
                AnimatedBuilder(
                  animation: _actionsController,
                  builder: (context, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section title (uses first action slot's animation)
                        FadeTransition(
                          opacity: _actionFades[0],
                          child: SlideTransition(
                            position: _actionSlides[0],
                            child: Text(
                              'Admin Governance Operations',
                              style: AppTypography.title.copyWith(
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Action items with staggered entry
                        ...List.generate(actions.length, (i) {
                          return FadeTransition(
                            opacity: _actionFades[i],
                            child: SlideTransition(
                              position: _actionSlides[i],
                              child: actions[i],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // ═══════════════════════════════════════════════════════════════
                // 4. VILLAGE CENSUS & AREA CARD — Fades in with actions
                // ═══════════════════════════════════════════════════════════════
                if (village != null) ...[
                  FadeTransition(
                    opacity: _actionFades.last,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Village Census & FRA Domain Summary',
                          style: AppTypography.title.copyWith(color: context.colors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppCard(
                          elevation: AppElevation.flat,
                          child: Column(
                            children: [
                              _InfoRow('गाव / Village Name', '${village.nameMarathi} (${village.nameEnglish})'),
                              _InfoRow('तालुका / Taluka', '${village.talukaMarathi} (${village.talukaEnglish})'),
                              _InfoRow('जिल्हा / District', '${village.districtMarathi} (${village.districtEnglish})'),
                              _InfoRow('लोकसंख्या / Census Population', '~${village.totalPopulation}'),
                              _InfoRow('नोंदणीकृत सदस्य / Adult Members', '${village.registeredAdultMembers}'),
                              _InfoRow('महिला सदस्य / Women Members', '${village.registeredWomenMembers}'),
                              _InfoRow('ST / Tribal Demographic', '${(village.stPercentage * 100).toStringAsFixed(0)}%'),
                              _InfoRow('मंजूर दावे / Approved Claims', '${village.totalApprovedClaims}'),
                              _InfoRow('एकूण क्षेत्र / Confirmed Domain', '${village.totalApprovedAreaHectares.toStringAsFixed(1)} Hectares'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
        ],
      ),
    );
  }



  // ── Build action items list ─────────────────────────────────────────────
  List<Widget> _buildActions(BuildContext context, WidgetRef ref, String totalClaims) {
    return [
      ActionListItem(
        icon: Icons.add_circle_outline_rounded,
        title: context.tr('action_schedule_meeting'),
        subtitle: 'Schedule New Gram Sabha & Define Agenda',
        iconColor: AppColors.saffron,
        onTap: () => Navigator.pushNamed(context, AppRouter.createMeeting),
      ),
      ActionListItem(
        icon: Icons.campaign_rounded,
        title: context.tr('action_post_notice'),
        subtitle: 'Broadcast High-Priority Notice to Village Board',
        iconColor: AppColors.govtBlue,
        onTap: () async {
          await ref.read(noticesProvider.notifier).postAdminNotice(
            titleMr: 'महत्त्वाची सूचना: विशेष ग्रामसभा',
            titleEn: 'Important Notice: Special Gram Sabha',
            bodyMr: 'पुढील आठवड्यात वन हक्क दाव्यांच्या मंजुरीसाठी विशेष बैठक होणार आहे.',
            bodyEn: 'A special Gram Sabha is scheduled next week for FRA claim validation.',
            category: NoticeCategory.general,
            severity: NoticeSeverity.info,
            validUntil: DateTime.now().add(const Duration(days: 14)),
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notice broadcasted to village board!')),
            );
          }
        },
      ),
      ActionListItem(
        icon: Icons.fact_check_rounded,
        title: context.tr('action_review_claims'),
        subtitle: 'Inspect Evidence & Adjudicate Pending FRA Claims',
        iconColor: AppColors.warningAmber,
        onTap: () => widget.onSwitchTab?.call(AppTab.claims.index),
      ),
      ActionListItem(
        icon: Icons.how_to_reg_rounded,
        title: context.tr('action_attendance'),
        subtitle: 'Manage Attendance & Quorum Verification Dashboard',
        iconColor: AppColors.successGreen,
        onTap: () => widget.onSwitchTab?.call(AppTab.sabha.index),
      ),
      ActionListItem(
        icon: Icons.gavel_rounded,
        title: context.tr('action_record_resolution'),
        subtitle: 'Record Official Resolution & Publish to Ledger',
        iconColor: AppColors.forestSage,
        onTap: () => widget.onSwitchTab?.call(AppTab.sabha.index),
      ),
      ActionListItem(
        icon: Icons.map_rounded,
        title: context.tr('action_map_monitor'),
        subtitle: 'CFR Boundary Map & encroachment Alert Monitoring',
        iconColor: AppColors.forestCanopy,
        onTap: () => widget.onSwitchTab?.call(AppTab.map.index),
      ),
    ];
  }
}

// ─── Info Row (unchanged) ─────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: c.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: AppTypography.subtitle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Wrappers (unchanged) ─────────────────────────────────────────────────

class _AdminGramSabhaTab extends StatelessWidget {
  final Widget bottomNavigationBar;
  const _AdminGramSabhaTab({required this.bottomNavigationBar});

  @override
  Widget build(BuildContext context) => GramSabhaDashboard(bottomNavigationBar: bottomNavigationBar);
}

class _AdminMapTab extends StatelessWidget {
  final Widget bottomNavigationBar;
  const _AdminMapTab({required this.bottomNavigationBar});

  @override
  Widget build(BuildContext context) => BoundaryMapScreen(bottomNavigationBar: bottomNavigationBar);
}

class _AdminProfileTab extends StatelessWidget {
  final Widget bottomNavigationBar;
  const _AdminProfileTab({required this.bottomNavigationBar});

  @override
  Widget build(BuildContext context) => ProfileScreen(bottomNavigationBar: bottomNavigationBar);
}
