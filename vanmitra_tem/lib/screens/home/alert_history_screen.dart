import 'package:flutter/material.dart';
import '../../models/boundary_alert.dart';
import '../../services/module_b_service.dart';
import '../../widgets/common/app_components.dart';
import '../../widgets/portal_frame_scaffold.dart';
import 'alert_detail_screen.dart';

/// Module B — Screen #15: Satellite Alert History Log
///
/// Filterable list of all boundary_alerts for the village.
/// Filters: tier (🔴/🟡/🟢), likely cause, resolution feasibility.
/// Each card shows claimant name, survey no., tier badge, area affected, date.
///
/// Route: /map/alerts
class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  final _svc = SeedModuleBService();

  AlertTier? _tierFilter;
  String? _causeFilter;
  ResolutionFeasibility? _feasibilityFilter;

  List<BoundaryAlert> _allAlerts = [];
  bool _loading = true;

  static const String _causeAll = 'All';
  static const String _causeClear = 'Illegal Clearing / Logging';
  static const String _causeNone = 'No change detected';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final alerts = await _svc.getAlerts('ozar');
    if (mounted) setState(() { _allAlerts = alerts; _loading = false; });
  }

  List<BoundaryAlert> get _filtered {
    return _allAlerts.where((a) {
      if (_tierFilter != null && a.tier != _tierFilter) return false;
      if (_causeFilter != null && _causeFilter != _causeAll) {
        if (a.likelyCause != _causeFilter) return false;
      }
      if (_feasibilityFilter != null && a.resolutionFeasibility != _feasibilityFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        // Red first, then yellow, then green
        final tierOrder = {'red': 0, 'yellow': 1, 'green': 2};
        return (tierOrder[a.tier.name] ?? 2).compareTo(tierOrder[b.tier.name] ?? 2);
      });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final redCount = _allAlerts.where((a) => a.tier == AlertTier.red).length;
    final yellowCount = _allAlerts.where((a) => a.tier == AlertTier.yellow).length;
    final greenCount = _allAlerts.where((a) => a.tier == AlertTier.green).length;

    final c = context.colors;
    return PortalFrameScaffold(
      breadcrumbs: const ['Map', 'Alert History'],
      body: Column(
        children: [
          // ── Summary Stats Bar ──────────────────────────────────────────
          Container(
            color: c.cardBg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
            child: Row(
              children: [
                _StatChip('🔴 $redCount Red', AppColors.alertRed,
                    selected: _tierFilter == AlertTier.red,
                    onTap: () => setState(() =>
                        _tierFilter = _tierFilter == AlertTier.red ? null : AlertTier.red)),
                const SizedBox(width: AppSpacing.sm),
                _StatChip('🟡 $yellowCount Amber', AppColors.warningAmber,
                    selected: _tierFilter == AlertTier.yellow,
                    onTap: () => setState(() =>
                        _tierFilter = _tierFilter == AlertTier.yellow ? null : AlertTier.yellow)),
                const SizedBox(width: AppSpacing.sm),
                _StatChip('🟢 $greenCount Stable', AppColors.successGreen,
                    selected: _tierFilter == AlertTier.green,
                    onTap: () => setState(() =>
                        _tierFilter = _tierFilter == AlertTier.green ? null : AlertTier.green)),
              ],
            ),
          ),

          // ── Filter Chips ───────────────────────────────────────────────
          Container(
            color: c.cardBg,
            padding: const EdgeInsets.only(
                left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Cause filter
                  _FilterPill('All Causes', _causeFilter == null || _causeFilter == _causeAll,
                      () => setState(() => _causeFilter = null)),
                  const SizedBox(width: 8),
                  _FilterPill('Clearing/Logging', _causeFilter == _causeClear,
                      () => setState(() => _causeFilter = _causeClear)),
                  const SizedBox(width: 8),
                  _FilterPill('No Change', _causeFilter == _causeNone,
                      () => setState(() => _causeFilter = _causeNone)),
                  const SizedBox(width: 16),
                  // Feasibility filter
                  _FilterPill('Reliable only', _feasibilityFilter == ResolutionFeasibility.reliable,
                      () => setState(() =>
                          _feasibilityFilter = _feasibilityFilter == ResolutionFeasibility.reliable
                              ? null : ResolutionFeasibility.reliable)),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: c.border),

          // ── Count Bar ─────────────────────────────────────────────────
          Container(
            color: c.sunkenBg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${filtered.length} parcels',
                  style: AppTypography.caption.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Ozar Village · demo-v1-synthetic',
                  style: AppTypography.caption.copyWith(
                    color: c.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),

          // ── Alerts List ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.forestCanopy)))
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.satellite_alt_rounded,
                        title: 'No matching alerts',
                        description: 'Try adjusting your filter criteria.',
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 90),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _AlertCard(
                          alert: filtered[i],
                          onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => AlertDetailScreen(alert: filtered[i]),
                          )),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatChip(this.label, this.color, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: selected ? 1.0 : 0.35)),
        ),
        child: Text(label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          )),
      ),
    );
  }
}

// ── Filter Pill ───────────────────────────────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (c.isDark ? AppColors.forestDeep : AppColors.forestSage.withValues(alpha: 0.15))
              : c.chipUnselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (c.isDark ? AppColors.accentSaffron : AppColors.forestSage)
                : c.chipUnselectedBorder,
            width: 1.2,
          ),
        ),
        child: Text(label,
          style: AppTypography.caption.copyWith(
            color: selected
                ? (c.isDark ? AppColors.accentSaffron : AppColors.forestCanopy)
                : c.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          )),
      ),
    );
  }
}

// ── Alert Card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final BoundaryAlert alert;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tierColor = Color(alert.tier.argbColor);
    final isGreen = alert.tier == AlertTier.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 5),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            // Tier dot
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tierColor.withValues(alpha: 0.12),
                border: Border.all(color: tierColor.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(alert.tier.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.claimantName ?? 'Unknown',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          isGreen ? 'Stable' : alert.tier.displayNameEn,
                          style: AppTypography.caption.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Survey ${alert.surveyNo ?? "N/A"} · ${alert.landUseType ?? ""}',
                    style: AppTypography.caption.copyWith(color: c.textSecondary),
                  ),
                  if (!isGreen && alert.areaAffectedSqm != null && alert.areaAffectedSqm! > 0)
                    Text(
                      'Affected: ${alert.areaAffectedSqm!.toStringAsFixed(0)} m²  '
                      '· ${alert.likelyCause ?? ""}',
                      style: AppTypography.caption.copyWith(
                        color: tierColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  if (alert.resolutionFeasibility != null &&
                      alert.resolutionFeasibility!.needsWarning)
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 12, color: AppColors.warningAmber),
                        const SizedBox(width: 4),
                        Text(
                          '${alert.resolutionFeasibility!.label} accuracy',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11, color: AppColors.warningAmber),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: c.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
