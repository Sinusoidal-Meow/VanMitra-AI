import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/routes/app_router.dart';
import '../../models/boundary_alert.dart';
import '../../models/claim.dart';
import '../../providers/claims_provider.dart';
import '../../services/localization_service.dart';
import '../../services/module_b_service.dart';
import '../../widgets/common/app_components.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/status_timeline_widget.dart';
import '../home/alert_detail_screen.dart';

/// Renovated My Claims List — FRA Citizen Application directory built on Forest Canopy tokens,
/// StatusBadge tracking tags, floating card hierarchy, and standardized empty state representation.
class MyClaimsScreen extends ConsumerStatefulWidget {
  final Widget? bottomNavigationBar;
  const MyClaimsScreen({super.key, this.bottomNavigationBar});

  @override
  ConsumerState<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends ConsumerState<MyClaimsScreen> {
  final _searchCtrl = TextEditingController();
  ClaimStatus? _filterStatus;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(userClaimsStreamProvider);

    if (claimsAsync.isLoading) {
      return PortalFrameScaffold(
        breadcrumbs: [context.tr('tab_dashboard'), context.tr('title_my_claims')],
        bottomNavigationBar: widget.bottomNavigationBar,
        body: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.forestCanopy))),
      );
    }

    if (claimsAsync.hasError) {
      return PortalFrameScaffold(
        breadcrumbs: [context.tr('tab_dashboard'), context.tr('title_my_claims')],
        bottomNavigationBar: widget.bottomNavigationBar,
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: context.tr('error_loading_claims') /* Error loading claims from cloud */,
          description: 'Please verify your connectivity or check local offline storage.',
        ),
      );
    }

    final allClaims = claimsAsync.value ?? [];

    var filtered = allClaims.where((c) {
      final matchSearch = _searchQuery.isEmpty ||
          c.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.claimantName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchFilter = _filterStatus == null || c.status == _filterStatus;
      return matchSearch && matchFilter;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PortalFrameScaffold(
      breadcrumbs: [context.tr('tab_dashboard'), context.tr('title_my_claims')],
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, AppRouter.claimType),
          backgroundColor: AppColors.saffron,
          foregroundColor: Colors.white,
          elevation: 6,
          extendedPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          icon: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
          label: Text(
            context.tr('action_new_claim'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar (DBT Application Tracker pattern) ────────────────────
          Container(
            color: context.colors.cardBg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppTypography.body.copyWith(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: context.tr('search_placeholder') /* Search by application ID or claimant */,
                hintStyle: AppTypography.caption.copyWith(color: context.colors.textTertiary),
                prefixIcon: Icon(Icons.search_rounded, color: context.colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.forestSage, width: 2),
                ),
                filled: true,
                fillColor: context.colors.sunkenBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          // ── Status Filter Chips ──────────────────────────────────────────
          Container(
            color: context.colors.cardBg,
            padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterChip(
                    label: context.tr('filter_all') /* All Claims */,
                    selected: _filterStatus == null,
                    onTap: () => setState(() => _filterStatus = null),
                    color: AppColors.forestCanopy,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final s in ClaimStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _FilterChip(
                        label: s.getLocalizedStatus(context),
                        selected: _filterStatus == s,
                        onTap: () => setState(() => _filterStatus = s),
                        color: _statusColor(s),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Summary Metrics Bar ──────────────────────────────────────────
          Container(
            color: context.colors.sunkenBg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
            child: Row(
              children: [
                _StatPill(
                  '${allClaims.where((c) => c.status == ClaimStatus.approved).length}',
                  context.tr('filter_approved'),
                  AppColors.successGreen,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatPill(
                  '${allClaims.where((c) => c.status == ClaimStatus.underReview || c.status == ClaimStatus.submitted).length}',
                  context.tr('filter_pending'),
                  AppColors.warningAmber,
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatPill(
                  '${allClaims.where((c) => c.status == ClaimStatus.rejected).length}',
                  context.tr('filter_rejected'),
                  AppColors.alertRed,
                ),
                const Spacer(),
                Text(
                  '${filtered.length} ${context.tr('claims_count_suffix')}',
                  style: AppTypography.caption.copyWith(color: context.colors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border),

          // ── Claims Directory List ────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.folder_shared_outlined,
                    title: (_filterStatus != null || _searchQuery.isNotEmpty)
                        ? context.tr('no_claims_filter') /* No matching applications found */
                        : context.tr('no_claims_yet') /* No FRA claims filed yet */,
                    description: (_filterStatus != null || _searchQuery.isNotEmpty)
                        ? 'Try modifying your filter criteria or clear the search query.'
                        : 'Begin securing your forest community land rights under FRA 2006 today.',
                    ctaLabel: (_filterStatus == null && _searchQuery.isEmpty) ? context.tr('action_new_claim') : null,
                    onCtaPressed: (_filterStatus == null && _searchQuery.isEmpty)
                        ? () => Navigator.pushNamed(context, AppRouter.claimType)
                        : null,
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 90),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _ClaimTile(claim: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ClaimStatus s) {
    switch (s) {
      case ClaimStatus.approved:
        return AppColors.successGreen;
      case ClaimStatus.rejected:
        return AppColors.alertRed;
      case ClaimStatus.underReview:
      case ClaimStatus.submitted:
        return AppColors.warningAmber;
      default:
        return AppColors.textTertiary;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final effectiveColor = (selected && c.isDark && color == AppColors.forestCanopy)
        ? AppColors.forestSage
        : color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? effectiveColor : c.chipUnselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? effectiveColor : c.chipUnselectedBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.textOnBrand : c.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _StatPill(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: AppTypography.subtitle.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  final Claim claim;
  const _ClaimTile({required this.claim});

  StatusType _toStatusType() {
    switch (claim.status) {
      case ClaimStatus.approved:
        return StatusType.verified;
      case ClaimStatus.rejected:
        return StatusType.error;
      case ClaimStatus.underReview:
      case ClaimStatus.submitted:
        return StatusType.pending;
      default:
        return StatusType.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = DateFormat('dd/MM/yyyy');
    final isRejected = claim.status == ClaimStatus.rejected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: AppCard(
        elevation: AppElevation.floating,
        onTap: () => Navigator.pushNamed(context, AppRouter.claimForm, arguments: claim.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rejection & Appeal Notification Banner
            if (isRejected && claim.isAppealWindowOpen)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.alertRed, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${context.tr('appeal_deadline')}: ${claim.appealDaysRemaining} ${context.tr('days_left')}',
                      style: AppTypography.caption.copyWith(color: AppColors.alertRed, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRouter.rejectionCheck, arguments: claim.id),
                      child: Text(
                        context.tr('appeal_now') /* Appeal Now */,
                        style: AppTypography.caption.copyWith(color: AppColors.alertRed, fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.isDark
                        ? AppColors.forestMist.withValues(alpha: 0.15)
                        : AppColors.forestCanopy.withValues(alpha: 0.08),
                    border: Border.all(
                      color: c.isDark
                          ? AppColors.forestMist.withValues(alpha: 0.4)
                          : AppColors.forestSage.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(claim.status.icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              claim.claimantName,
                              style: AppTypography.title.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(label: claim.status.displayNameMr, status: _toStatusType()),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('application_no')}: ${claim.id.length > 12 ? "${claim.id.substring(0, 12)}…" : claim.id}',
                        style: AppTypography.caption.copyWith(color: c.textTertiary, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr('survey_no')}: ${claim.surveyNumber ?? "N/A"}  •  ${claim.areaSqMeters?.toStringAsFixed(0) ?? "?"} ${context.tr('sq_meters')}',
                        style: AppTypography.body.copyWith(fontSize: 13, color: c.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr('date_prefix')}: ${fmt.format(claim.createdAt)}',
                        style: AppTypography.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 22),
              ],
            ),

            // Mini Status Progression Timeline
            if (claim.status != ClaimStatus.draft) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: c.border),
              const SizedBox(height: AppSpacing.md),
              StatusTimelineWidget(
                steps: [
                  context.tr('step_received') /* Received */,
                  context.tr('step_verification') /* Verification */,
                  context.tr('step_gramsabha') /* Gram Sabha */,
                  context.tr('step_decision') /* Adjudication */,
                ],
                currentStep: _timelineStep(),
                isRejected: claim.status == ClaimStatus.rejected,
              ),
              const SizedBox(height: AppSpacing.md),
              _SatelliteTierBadge(surveyNo: claim.surveyNumber),
            ],
          ],
        ),
      ),
    );
  }

  int _timelineStep() {
    switch (claim.status) {
      case ClaimStatus.submitted:
        return 0;
      case ClaimStatus.underReview:
        return 1;
      case ClaimStatus.appealFiled:
        return 2;
      case ClaimStatus.approved:
      case ClaimStatus.rejected:
        return 3;
      default:
        return 0;
    }
  }
}

// ── Satellite Tier Badge ──────────────────────────────────────────────────────
/// Inline satellite monitoring badge shown within each claim card.
/// Looks up the alert for this claim's survey number from seed data.
class _SatelliteTierBadge extends StatefulWidget {
  final String? surveyNo;
  const _SatelliteTierBadge({this.surveyNo});

  @override
  State<_SatelliteTierBadge> createState() => _SatelliteTierBadgeState();
}

class _SatelliteTierBadgeState extends State<_SatelliteTierBadge> {
  BoundaryAlert? _alert;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.surveyNo == null) return;
    final svc = SeedModuleBService();
    final alerts = await svc.getAlerts('ozar');
    final surveyNum = int.tryParse(widget.surveyNo!);
    if (surveyNum == null) return;
    try {
      final found = alerts.firstWhere((a) => a.surveyNo == surveyNum);
      if (mounted) setState(() => _alert = found);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tier = _alert?.tier ?? AlertTier.green;
    final tierColor = Color(tier.argbColor);
    final cause = _alert?.likelyCause ?? 'Monitoring active';

    return GestureDetector(
      onTap: _alert != null
          ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AlertDetailScreen(alert: _alert!)))
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tierColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: tierColor.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tier.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Icon(Icons.satellite_alt_rounded, size: 14, color: tierColor),
            const SizedBox(width: 5),
            Text(
              'Satellite: $cause',
              style: AppTypography.caption.copyWith(
                color: tierColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            if (_alert != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded, size: 12, color: context.colors.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}

