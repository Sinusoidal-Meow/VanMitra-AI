// A claim's own page: summary, the sent-back banner, the steps of the claim (each opening
// its screen, with a status worked out from the server's records) and the actions the
// server allows right now (allowed_actions).
//   Form C (cfr): 1 Form · 2 Evidence · 3 Boundary · 4 Field verification ·
//                 5 Gram Sabha decision · 6 Status & title
//   Form B (cr):  1 Form · 2 Evidence · 3 Gram Sabha decision · 4 Status & title

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/deadline_banner.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/villager_ui/villager_ui.dart';
import '../evidence/evidence_api.dart';
import '../evidence/evidence_screen.dart';
import '../form_a/form_a_screen.dart';
import '../form_b/form_b_screen.dart';
import '../form_c/form_c_screen.dart';
import '../mapping/boundary_screen.dart';
import '../mapping/mapping_api.dart';
import 'case_hub_api.dart';
import 'case_stage_screens.dart';

enum _StepState { done, active, needsAction, waiting }

class _Step {
  const _Step(this.title, this.subtitle, this.icon, this.state, this.status, this.onTap);
  final String title;
  final String subtitle;
  final IconData icon;
  final _StepState state;
  final String status;
  final VoidCallback onTap;
}

class CaseHomeScreen extends StatefulWidget {
  final String caseId;
  final String? initialClaimType;

  const CaseHomeScreen({super.key, required this.caseId, this.initialClaimType});

  @override
  State<CaseHomeScreen> createState() => _CaseHomeScreenState();
}

class _CaseHomeScreenState extends State<CaseHomeScreen> {
  final CaseHubApi _api = CaseHubApi();
  bool _loading = true;
  Object? _error;
  Map<String, dynamic>? _case;
  List<Map<String, dynamic>> _evidence = [];
  Map<String, dynamic>? _boundary;
  List<dynamic> _verifications = [];
  List<dynamic> _resolutions = [];
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadCase();
  }

  /// A failing side record must not hide the claim itself.
  Future<T?> _soft<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCase() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getCaseDetails(widget.caseId);
      final isCfr = data['claim_type'] == 'cfr';
      final side = await Future.wait([
        _soft(() => EvidenceApi().list(widget.caseId)),
        isCfr ? _soft(() => MappingApi().boundary(widget.caseId)) : Future.value(null),
        isCfr ? _soft(() => _api.verifications(widget.caseId)) : Future.value(null),
        _soft(() => _api.resolutions(widget.caseId)),
      ]);
      if (!mounted) return;
      setState(() {
        _case = data;
        _evidence = ((side[0] as List<Map<String, dynamic>>?) ?? [])
            .where((e) => e['superseded'] != true)
            .toList();
        _boundary = side[1] as Map<String, dynamic>?;
        _verifications = (side[2] as List<dynamic>?) ?? [];
        _resolutions = (side[3] as List<dynamic>?) ?? [];
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String get _claimType => _case?['claim_type'] as String? ?? widget.initialClaimType ?? 'cr';
  String get _state => _case?['state'] as String? ?? 'draft';
  bool get _isMine => _case?['is_mine'] == true;
  List<String> get _allowed => ((_case?['allowed_actions'] as List<dynamic>?) ?? []).cast<String>();

  /// The claimant while drafting; the Gram Sabha while it reviews.
  bool get _canWork =>
      (_state == 'draft' && _isMine) || (_state == 'gs_review' && _allowed.contains('approve'));

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadCase();
  }

  // ── Steps ──────────────────────────────────────────────────────────────────

  void _openClaimForm() {
    final editable = _state == 'draft' && _isMine;
    _push(switch (_claimType) {
      'ifr' => FormAScreen(caseId: widget.caseId, canEdit: editable),
      'cr' => FormBScreen(caseId: widget.caseId, canEdit: editable),
      _ => FormCScreen(caseId: widget.caseId, canEdit: editable, villageId: _case?['village_id'] as String?),
    });
  }

  void _openEvidence() => _push(EvidenceScreen(
        caseId: widget.caseId,
        claimType: _claimType,
        villageId: _case?['village_id'] as String? ?? '',
        canAdd: _canWork,
      ));

  void _openBoundary() => _push(BoundaryScreen(caseId: widget.caseId, canEdit: _canWork));

  void _openVerification() => _push(VerificationRecordScreen(caseId: widget.caseId));

  void _openGramSabhaDecision() =>
      _push(GramSabhaDecisionScreen(caseId: widget.caseId, claimType: _claimType));

  void _openStatus() => _push(ClaimStatusScreen(caseId: widget.caseId, state: _state));

  Future<void> _showHistory() async {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: c.bottomSheetBg,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, scroll) => FutureBuilder<List<dynamic>>(
          future: _api.history(widget.caseId),
          builder: (_, snap) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              Text('History · इतिहास',
                  style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (snap.hasError)
                Text(apiErrorText(snap.error!))
              else if (!snap.hasData)
                const Center(child: CircularProgressIndicator())
              else
                HistoryTimeline(events: snap.data!),
            ],
          ),
        ),
      ),
    );
  }

  List<_Step> _steps() {
    final isCfr = _claimType == 'cfr';
    final draft = _state == 'draft';
    final pastGs = const ['sdo_review', 'district_review', 'title_issued'].contains(_state);
    final steps = <_Step>[];

    // 1 · Form
    steps.add(_Step(
      'Claim form · दावा अर्ज',
      isCfr ? 'Form C: area, landmarks, bordering villages, evidence list' : 'Form B: claimants, rights claimed, evidence list',
      Icons.description_rounded,
      draft ? (_isMine ? _StepState.active : _StepState.waiting) : _StepState.done,
      draft ? (_isMine ? 'Fill and save' : 'Draft') : 'Submitted',
      _openClaimForm,
    ));

    // 2 · Evidence
    final n = _evidence.length;
    final verified = _evidence.where((e) => e['verified'] == true).length;
    steps.add(_Step(
      'Evidence · पुरावे (Rule 13)',
      'Photos of documents and places, statement of elders',
      Icons.photo_library_rounded,
      n >= 2 ? _StepState.done : (n > 0 ? _StepState.active : (_canWork ? _StepState.needsAction : _StepState.waiting)),
      n == 0 ? 'None yet' : '$n recorded${verified > 0 ? ' · $verified verified' : ''}',
      _openEvidence,
    ));

    if (isCfr) {
      // 3 · Boundary
      final b = _boundary;
      final missing = b?['segments_without_landmark'] as int? ?? 0;
      steps.add(_Step(
        'Boundary & landmarks · सीमा',
        'Walk or draw the boundary, a landmark on every side, use zones',
        Icons.map_rounded,
        b == null
            ? (_canWork ? _StepState.needsAction : _StepState.waiting)
            : (b['status'] != 'draft' ? _StepState.done : (missing > 0 ? _StepState.needsAction : _StepState.done)),
        b == null
            ? 'Not mapped yet'
            : b['status'] != 'draft'
                ? 'Approved · ${b['area_ha']} ha'
                : missing > 0
                    ? '${b['area_ha']} ha · $missing side${missing == 1 ? '' : 's'} need a landmark'
                    : 'Mapped · ${b['area_ha']} ha',
        _openBoundary,
      ));

      // 4 · Field verification
      final complete = _verifications.any((v) => (v as Map)['complete'] == true);
      steps.add(_Step(
        'Field verification · पडताळणी',
        'Joint visit by the FRC with Forest and Revenue officials',
        Icons.fact_check_rounded,
        complete ? _StepState.done : (_verifications.isNotEmpty ? _StepState.active : _StepState.waiting),
        complete ? 'Complete' : (_verifications.isNotEmpty ? 'In progress' : 'After you submit'),
        _openVerification,
      ));
    }

    // Gram Sabha decision
    final passed = _resolutions.any((r) => ((r as Map)['quorum_proof'] as Map?)?['passed'] == true);
    steps.add(_Step(
      'Gram Sabha decision · ठराव',
      'Meeting with quorum and the resolution on this claim',
      Icons.gavel_rounded,
      passed || pastGs ? _StepState.done : (_state == 'gs_review' ? _StepState.active : _StepState.waiting),
      passed || pastGs ? 'Resolution passed' : (_state == 'gs_review' ? 'With the Gram Sabha' : 'After you submit'),
      _openGramSabhaDecision,
    ));

    // Status & title
    steps.add(_Step(
      'Status & title · सनद',
      'Receipt, SDO and district stages, the title draft',
      Icons.workspace_premium_rounded,
      switch (_state) {
        'title_issued' => _StepState.done,
        'rejected' || 'expired' => _StepState.needsAction,
        'sdo_review' || 'district_review' => _StepState.active,
        _ => _StepState.waiting,
      },
      claimStateLabel(_state),
      _openStatus,
    ));
    return steps;
  }

  // ── Workflow actions ───────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String body, String yes, Color color) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _askRemarks(String title, String help, String yes, Color color, int minLength) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(help, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 4,
                autofocus: true,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  labelText: 'Remarks (at least $minLength letters)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: ctrl.text.trim().length >= minLength ? () => Navigator.pop(ctx, ctrl.text.trim()) : null,
              child: Text(yes),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return text;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _actionInProgress = true);
    try {
      await action();
      if (mounted) showDone(context, done);
      await _loadCase();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!await _confirm(
      'Submit claim · दावा दाखल करा',
      'Send this claim to the Gram Sabha? The form will be locked while it is reviewed, and you get a receipt number.\n\nहा दावा ग्रामसभेकडे पाठवायचा का?',
      'Submit',
      const Color(0xFF2E705B),
    )) return;
    await _run(() => _api.submitCase(widget.caseId), 'Claim submitted to the Gram Sabha.');
  }

  Future<void> _handleApprove() async {
    if (!await _confirm('Approve & forward', 'Approve this claim and send it to the next level?', 'Approve',
        const Color(0xFF2E7D32))) return;
    await _run(() => _api.approveCase(widget.caseId), 'Claim approved and forwarded.');
  }

  Future<void> _handleReturn() async {
    final remarks = await _askRemarks(
      'Send back for corrections',
      'Say what needs to be corrected. The claimant gets 60 days to fix and resubmit.',
      'Send back',
      const Color(0xFFB45300),
      5,
    );
    if (remarks == null) return;
    await _run(() => _api.returnCase(widget.caseId, remarks), 'Claim sent back with your remarks.');
  }

  Future<void> _handleReject() async {
    final remarks = await _askRemarks(
      'Reject with reasons',
      'A claim is never rejected without written reasons [Rule 12A(7)].',
      'Reject',
      const Color(0xFFC62828),
      10,
    );
    if (remarks == null) return;
    await _run(() => _api.rejectCase(widget.caseId, remarks), 'Claim rejected with reasons.');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final letter = _case?['form'] as String? ??
        switch (_claimType) {
          'ifr' => 'A',
          'cr' => 'B',
          _ => 'C',
        };
    return PortalFrameScaffold(
      breadcrumbs: ['Dashboard', 'My Claims', 'Form $letter'],
      actions: [
        IconButton(
          tooltip: 'History',
          icon: const Icon(Icons.history_rounded, color: Colors.white),
          onPressed: _case == null ? null : _showHistory,
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadCase,
        ),
      ],
      bottomNavigationBar: _case == null ? null : _actionBar(),
      body: _loading && _case == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _case == null
              ? Center(
                  child: VillagerEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load the claim',
                    message: apiErrorText(_error!),
                    actionLabel: 'Try again',
                    actionIcon: Icons.refresh_rounded,
                    onAction: _loadCase,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCase,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      const NatureBanner(height: 78),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _summaryCard(letter),
                            const SizedBox(height: 12),
                            if (_case!['returned'] != null) _returnedBanner(_case!['returned'] as Map<String, dynamic>),
                            if (_state == 'draft' && _isMine) _hint(),
                            const VmSectionTitle('Steps of your claim', subtitle: 'Tap a step to open it.'),
                            ..._stepTiles(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard(String letter) {
    final c = context.colors;
    final d = _case!;
    final created = DateTime.tryParse(d['created_at'] as String? ?? '');
    final claimant = (d['claimant_label'] as String?)?.trim() ?? '';
    final isCfr = _claimType == 'cfr';
    final accent = isCfr ? const Color(0xFF2E705B) : const Color(0xFFFF7A00);
    return VmCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Text(letter, style: TextStyle(color: accent, fontSize: 24, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formTitle(_claimType),
                    style: TextStyle(color: c.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(claimant.isEmpty ? 'Claimant not filled in yet' : claimant,
                    style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: c.textTertiary),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text('${d['village_name_mr'] ?? d['village_name_en']} · ${d['taluka']}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textTertiary, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(label: claimStateLabel(_state), color: claimStateColor(_state)),
                    if (created != null)
                      Text('Opened ${DateFormat('d MMM yyyy').format(created.toLocal())}',
                          style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _returnedBanner(Map<String, dynamic> r) => DeadlineBanner(
        remarks: r['remarks'] as String? ?? '',
        daysLeft: r['days_left'] as int? ?? 60,
        returnedByName: r['by_name'] as String?,
        returnedByRole: r['by_role'] as String?,
      );

  Widget _hint() {
    final isCfr = _claimType == 'cfr';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD8A8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_rounded, color: Color(0xFFE07A00), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isCfr
                    ? 'Fill the form, add evidence and map the boundary with a landmark on every side. Then press Submit at the bottom.'
                    : 'Fill the form and add evidence. Then press Submit at the bottom.',
                style: const TextStyle(color: Color(0xFF7A4100), fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stepTiles() {
    final steps = _steps();
    return [
      for (var i = 0; i < steps.length; i++) _StepTile(number: i + 1, step: steps[i], last: i == steps.length - 1),
    ];
  }

  Widget? _actionBar() {
    final allowed = _allowed;
    if (allowed.isEmpty) return null;
    final busy = _actionInProgress;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: context.colors.cardBg,
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -3))],
        ),
        child: Row(
          children: [
            if (allowed.contains('reject')) ...[
              OutlinedButton(
                onPressed: busy ? null : _handleReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFC62828)),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
            ],
            if (allowed.contains('return')) ...[
              OutlinedButton(
                onPressed: busy ? null : _handleReturn,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB45300),
                  side: const BorderSide(color: Color(0xFFB45300)),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Send back'),
              ),
              const SizedBox(width: 8),
            ],
            if (allowed.contains('submit'))
              Expanded(
                child: OrangePillButton(
                    label: 'Submit claim · दाखल करा',
                    icon: Icons.send_rounded,
                    busy: busy,
                    onPressed: _handleSubmit),
              ),
            if (allowed.contains('approve'))
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : _handleApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve & forward'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.step, required this.last});

  final int number;
  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon) = switch (step.state) {
      _StepState.done => (const Color(0xFF2E7D32), Icons.check_circle_rounded),
      _StepState.active => (const Color(0xFF1E6FB8), Icons.play_circle_fill_rounded),
      _StepState.needsAction => (const Color(0xFFE07A00), Icons.error_rounded),
      _StepState.waiting => (const Color(0xFF94A3B8), Icons.schedule_rounded),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    color: step.state == _StepState.done ? color : c.cardBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: step.state == _StepState.done
                      ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                      : Text('$number', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                ),
                if (!last) Expanded(child: Container(width: 2, color: c.divider)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VmCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                radius: 18,
                onTap: step.onTap,
                borderColor: step.state == _StepState.needsAction ? const Color(0xFFFFD8A8) : null,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E705B).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(step.icon, color: const Color(0xFF2E705B)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title,
                              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
                          const SizedBox(height: 2),
                          Text(step.subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(icon, size: 14, color: color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(step.status,
                                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
