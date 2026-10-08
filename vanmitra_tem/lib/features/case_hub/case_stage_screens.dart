// Read-only stage pages of a claim, for the claimant: what the Gram Sabha recorded at
// the joint field visit (Step 4), its meeting decision (Step 5), and the claim's status:
// receipt, title draft and full history (Step 6). The Gram Sabha's own recording
// screens come with its dashboard design.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../evidence/evidence_screen.dart' show MediaImage;
import 'case_hub_api.dart';

String _d(String? iso) {
  final t = iso == null ? null : DateTime.tryParse(iso);
  return t == null ? '' : DateFormat('d MMM yyyy').format(t.toLocal());
}

/// Common frame: breadcrumb, small banner, pull-to-refresh, loading and error states.
class _StagePage extends StatelessWidget {
  const _StagePage({
    required this.crumb,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.children,
  });

  final String crumb;
  final bool loading;
  final Object? error;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PortalFrameScaffold(
      breadcrumbs: ['Dashboard', 'My Claims', crumb],
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            const NatureBanner(height: 78),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()))
                  : error != null
                      ? VillagerEmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load this page',
                          message: apiErrorText(error!),
                          actionLabel: 'Try again',
                          actionIcon: Icons.refresh_rounded,
                          onAction: onRefresh,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _kv(BuildContext context, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k,
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

Widget _scan(BuildContext context, String? mediaId, String label) {
  if (mediaId == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(
              child: InteractiveViewer(child: MediaImage(mediaId: mediaId))),
        ),
      )),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
                width: 56,
                height: 56,
                child: MediaImage(mediaId: mediaId, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF1E6FB8), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

// ── Step 4 · Joint field verification ──────────────────────────────────────────

class VerificationRecordScreen extends StatefulWidget {
  const VerificationRecordScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<VerificationRecordScreen> createState() =>
      _VerificationRecordScreenState();
}

class _VerificationRecordScreenState extends State<VerificationRecordScreen> {
  bool _loading = true;
  Object? _error;
  List<dynamic> _visits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final v = await CaseHubApi().verifications(widget.caseId);
      if (mounted) {
        setState(() {
          _visits = v;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StagePage(
      crumb: 'Field verification',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      children: [
        const VmSectionTitle('Joint field verification',
            subtitle:
                'The FRC visits the area with Forest and Revenue officials [Rule 12A(1)(2)].'),
        if (_visits.isEmpty)
          const VillagerEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No field visit recorded yet.',
            message:
                'After you submit the claim, the Gram Sabha arranges the joint visit and records it here.',
          )
        else
          for (final v in _visits.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _visitCard(context, v as Map<String, dynamic>),
            ),
      ],
    );
  }

  Widget _visitCard(BuildContext context, Map<String, dynamic> v) {
    final c = context.colors;
    final presence = (v['presence'] as List<dynamic>? ?? []);
    final complete = v['complete'] == true;
    Widget tick(bool ok, bool absent, String who) => Row(
          children: [
            Icon(
                ok
                    ? Icons.check_circle_rounded
                    : absent
                        ? Icons.do_not_disturb_on_rounded
                        : Icons.radio_button_unchecked_rounded,
                size: 17,
                color: ok
                    ? const Color(0xFF2E7D32)
                    : absent
                        ? const Color(0xFF757575)
                        : const Color(0xFFE07A00)),
            const SizedBox(width: 6),
            Text(
                ok
                    ? '$who signed'
                    : absent
                        ? '$who absent (recorded)'
                        : '$who not signed yet',
                style: TextStyle(color: c.textPrimary, fontSize: 13)),
          ],
        );
    return VmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Visit ${v['attempt_no']} · ${_d(v['visit_on'] as String?)}',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              complete
                  ? const StatusPill(
                      label: 'Complete',
                      color: Color(0xFF2E7D32),
                      icon: Icons.check_rounded)
                  : const StatusPill(
                      label: 'Still open', color: Color(0xFFE07A00)),
            ],
          ),
          const SizedBox(height: 8),
          Text(v['observations'] as String? ?? '',
              style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 10),
          Text('Present',
              style: TextStyle(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5)),
          for (final p in presence)
            Text(
                '• ${(p as Map)['name']}${p['designation'] != null ? ', ${p['designation']}' : ''} (${p['department']})',
                style: TextStyle(color: c.textPrimary, fontSize: 13)),
          const SizedBox(height: 8),
          tick(v['forest_signed'] == true, v['forest_absence_recorded'] == true,
              'Forest official'),
          const SizedBox(height: 4),
          tick(v['revenue_signed'] == true,
              v['revenue_absence_recorded'] == true, 'Revenue official'),
          _scan(context, v['signed_scan_media_id'] as String?,
              'Signed verification report'),
        ],
      ),
    );
  }
}

// ── Step 5 · Gram Sabha decision ───────────────────────────────────────────────

const Map<String, String> _approvalText = {
  'approval.resolution_needed': 'A Gram Sabha resolution passed with quorum',
  'approval.boundary_not_approved': 'The boundary approved in that resolution',
  'approval.verification_open': 'The joint field verification completed',
  'approval.dispute_open': 'No boundary dispute left open',
};

class GramSabhaDecisionScreen extends StatefulWidget {
  const GramSabhaDecisionScreen(
      {super.key, required this.caseId, required this.claimType});
  final String caseId;
  final String claimType;

  @override
  State<GramSabhaDecisionScreen> createState() =>
      _GramSabhaDecisionScreenState();
}

class _GramSabhaDecisionScreenState extends State<GramSabhaDecisionScreen> {
  bool _loading = true;
  Object? _error;
  List<dynamic> _resolutions = [];
  Map<String, dynamic>? _check;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = CaseHubApi();
    try {
      final res = await api.resolutions(widget.caseId);
      Map<String, dynamic>? check;
      if (widget.claimType == 'cfr') {
        check = await api.approvalCheck(widget.caseId);
      }
      if (mounted) {
        setState(() {
          _resolutions = res;
          _check = check;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StagePage(
      crumb: 'Gram Sabha decision',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      children: [
        const VmSectionTitle('Gram Sabha decision · ग्रामसभा ठराव',
            subtitle:
                'The Gram Sabha passes a resolution on the claim in a meeting with quorum [Sec 6(1), Rule 4(2)].'),
        if (_check != null) ...[
          ChecklistCard(
            title: 'Before the Gram Sabha forwards it to the SDO',
            lines: [
              for (final i in (_check!['items'] as List<dynamic>))
                ChecklistLine(
                  ok: i['ok'] as bool,
                  text: _approvalText[i['message_key']] ??
                      (i['message_key'] as String),
                  rule: i['rule'] as String,
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        VmSectionTitle('Resolutions', trailing: Text('${_resolutions.length}')),
        if (_resolutions.isEmpty)
          const VillagerEmptyState(
            icon: Icons.gavel_rounded,
            title: 'No resolution yet.',
            message:
                'Once the Gram Sabha meets and decides on this claim, the resolution appears here.',
          )
        else
          for (final r in _resolutions.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _resolutionCard(context, r as Map<String, dynamic>),
            ),
      ],
    );
  }

  Widget _resolutionCard(BuildContext context, Map<String, dynamic> r) {
    final c = context.colors;
    final q = r['quorum_proof'] as Map<String, dynamic>? ?? {};
    final passed = q['passed'] == true;
    return VmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Resolution ${r['number']}',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              Text(_d(r['created_at'] as String?),
                  style: TextStyle(color: c.textTertiary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(r['decision_text'] as String? ?? '',
              style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(
                  label: '${r['votes_for']} for · ${r['votes_against']} against',
                  color: const Color(0xFF1E6FB8)),
              if (q.isNotEmpty)
                StatusPill(
                  label: passed
                      ? 'Quorum met · ${q['present']} present, ${q['women_present']} women'
                      : 'Quorum not met',
                  color: passed
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                  icon: passed ? Icons.check_rounded : Icons.close_rounded,
                ),
              if (r['boundary_id'] != null)
                const StatusPill(
                    label: 'Boundary approved',
                    color: Color(0xFF2E705B),
                    icon: Icons.lock_rounded),
            ],
          ),
          _scan(context, r['signed_scan_media_id'] as String?,
              'Signed resolution'),
        ],
      ),
    );
  }
}

// ── Step 6 · Status, receipt, title and history ────────────────────────────────

const Map<String, String> _actionText = {
  'submit': 'Submitted to the Gram Sabha',
  'approve': 'Approved and forwarded',
  'return': 'Sent back for corrections',
  'reject': 'Rejected',
  'expire': 'Expired (not resubmitted in 60 days)',
  'resubmit': 'Resubmitted',
};

class ClaimStatusScreen extends StatefulWidget {
  const ClaimStatusScreen({super.key, required this.caseId, required this.state});
  final String caseId;
  final String state;

  @override
  State<ClaimStatusScreen> createState() => _ClaimStatusScreenState();
}

class _ClaimStatusScreenState extends State<ClaimStatusScreen> {
  bool _loading = true;
  Object? _error;
  Map<String, dynamic>? _ack;
  Map<String, dynamic>? _title;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Receipt and title are optional: 409 just means "not yet".
  Future<Map<String, dynamic>?> _optional(
      Future<Map<String, dynamic>> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = CaseHubApi();
    try {
      final results = await Future.wait([
        _optional(() => api.acknowledgement(widget.caseId)),
        _optional(() => api.titleDraft(widget.caseId)),
        api.history(widget.caseId),
      ]);
      if (mounted) {
        setState(() {
          _ack = results[0] as Map<String, dynamic>?;
          _title = results[1] as Map<String, dynamic>?;
          _history = results[2] as List<dynamic>;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _StagePage(
      crumb: 'Status & title',
      loading: _loading,
      error: _error,
      onRefresh: _load,
      children: [
        VmSectionTitle('Status · ${claimStateLabel(widget.state)}'),
        VmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFF2E705B)),
                  const SizedBox(width: 8),
                  Text('Receipt · पोच पावती',
                      style: TextStyle(
                          color: c.textPrimary, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              if (_ack == null)
                Text('A receipt number is given when the claim is submitted [Rule 11(3)].',
                    style: TextStyle(color: c.textSecondary, fontSize: 13))
              else ...[
                _kv(context, 'Receipt no.', _ack!['serial'] as String),
                _kv(context, 'Date', _d(_ack!['acknowledged_on'] as String?)),
                _kv(context, 'Claim', '${_ack!['form']} · ${_ack!['claimant_label']}'),
                _kv(context, 'Village', '${_ack!['village']}, ${_ack!['gram_panchayat']}'),
                if (_ack!['filed_within_window'] != null)
                  _kv(context, 'Filed in time',
                      _ack!['filed_within_window'] == true ? 'Yes' : 'After the call for claims closed'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        VmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFFFF8A00)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        _title == null
                            ? 'Title · सनद'
                            : '${_title!['annexure']} · ${_title!['title']}',
                        style: TextStyle(
                            color: c.textPrimary, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_title == null)
                Text(
                    'The title draft appears once the claim reaches the district committee.',
                    style: TextStyle(color: c.textSecondary, fontSize: 13))
              else ...[
                StatusPill(
                    label: _title!['status'] == 'issued'
                        ? 'Issued'
                        : 'Draft for signature',
                    color: _title!['status'] == 'issued'
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE07A00)),
                const SizedBox(height: 8),
                for (final e in (_title!['fields'] as Map<String, dynamic>).entries)
                  _kv(context, e.key.replaceAll('_', ' '),
                      e.value is List ? (e.value as List).join(', ') : '${e.value ?? ''}'),
                const SizedBox(height: 6),
                Text(_title!['note'] as String? ?? '',
                    style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const VmSectionTitle('History'),
        HistoryTimeline(events: _history),
      ],
    );
  }
}

/// Every action on the claim, oldest first: what, who (role), remarks, when.
class HistoryTimeline extends StatelessWidget {
  const HistoryTimeline({super.key, required this.events});
  final List<dynamic> events;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (events.isEmpty) {
      return Text('Nothing has happened to this claim yet.',
          style: TextStyle(color: c.textSecondary, fontSize: 13));
    }
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          Builder(builder: (context) {
            final e = events[i] as Map<String, dynamic>;
            final last = i == events.length - 1;
            final color = claimStateColor(e['to_state'] as String? ?? '');
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        if (!last)
                          Expanded(
                              child: Container(width: 2, color: c.divider)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_actionText[e['action']] ?? '${e['action']}',
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            '${e['actor_name']}${e['actor_role'] != null ? ' (${(e['actor_role'] as String).replaceAll('_', ' ')})' : ''} · ${_d(e['at'] as String?)}',
                            style: TextStyle(color: c.textSecondary, fontSize: 12),
                          ),
                          if (e['remarks'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('“${e['remarks']}”',
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
