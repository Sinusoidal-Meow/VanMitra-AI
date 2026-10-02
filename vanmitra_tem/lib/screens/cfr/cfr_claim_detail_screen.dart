import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cfr_claim_stage_data.dart';
import '../../models/claim.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claims_provider.dart';
import '../../services/cfr_workflow_service.dart';
import '../../widgets/cfr_evidence_list_widget.dart';
import '../../widgets/cfr_status_timeline_widget.dart';
import '../../widgets/portal_frame_scaffold.dart';

/// Stage-Aware Complete CFR Claim Detail Screen with Interactive Action Panels
class CfrClaimDetailScreen extends ConsumerStatefulWidget {
  final Claim claim;

  const CfrClaimDetailScreen({super.key, required this.claim});

  @override
  ConsumerState<CfrClaimDetailScreen> createState() =>
      _CfrClaimDetailScreenState();
}

class _CfrClaimDetailScreenState extends ConsumerState<CfrClaimDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CfrWorkflowService _workflowService = CfrWorkflowService();
  late Claim _currentClaim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentClaim = widget.claim;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateClaim(TransitionResult result) {
    if (result.isSuccess && result.updatedClaim != null) {
      setState(() {
        _currentClaim = result.updatedClaim!;
      });
      ref.read(claimsProvider.notifier).updateClaim(_currentClaim);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workflow action recorded successfully!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage),
          backgroundColor: AppColors.alertRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final currentUser = auth.currentUser;

    return PortalFrameScaffold(
      breadcrumbs: [_currentClaim.id],
      body: Column(
        children: [
          // Header Summary Card
          _buildHeaderCard(context),

          // Tabs: Action Panel, Timeline, Evidence, Audit Log
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.forestCanopy,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: AppColors.saffron,
            tabs: const [
              Tab(icon: Icon(Icons.gavel_rounded), text: 'Workflow Action'),
              Tab(icon: Icon(Icons.timeline_rounded), text: 'Stage Timeline'),
              Tab(icon: Icon(Icons.folder_rounded), text: 'Evidence Dossier'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Audit Trail'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Stage Action Panel
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildStageActionPanel(context, currentUser),
                ),

                // Tab 2: Visual 8-Stage Timeline
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: CfrStatusTimelineWidget(claim: _currentClaim),
                ),

                // Tab 3: Evidence Dossier
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: CfrEvidenceListWidget(
                    evidenceList: _currentClaim.evidenceList,
                    isEditable: currentUser?.role == UserRole.villager ||
                        currentUser?.role == UserRole.frc,
                    onEvidenceListChanged: (updatedList) {
                      final updated =
                          _currentClaim.copyWith(evidenceList: updatedList);
                      _updateClaim(TransitionResult.success(updated));
                    },
                  ),
                ),

                // Tab 4: Audit Trail History
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildAuditLogTab(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.forestCanopy.withOpacity(0.06),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _currentClaim.id,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.forestCanopy,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentClaim.status.isApproved
                      ? AppColors.successGreen
                      : (_currentClaim.status.isRejected
                          ? AppColors.alertRed
                          : AppColors.saffron),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentClaim.status.displayNameEn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Community: ${_currentClaim.claimantNameEn} (${_currentClaim.claimantName})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${_currentClaim.villageName} • ${_currentClaim.tehsil} • ${_currentClaim.district}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.assignment_ind_rounded,
                  size: 14, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Text(
                'Assigned Authority: ${_currentClaim.assignedAuthority.displayNameEn}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.govtBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dynamic Stage Action Panel
  Widget _buildStageActionPanel(BuildContext context, user) {
    if (user == null) {
      return const Center(child: Text('Please log in to perform actions.'));
    }

    final isAuthorizedRole =
        user.role == _currentClaim.assignedAuthority ||
            user.role == UserRole.admin ||
            user.role == UserRole.slmc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isAuthorizedRole)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are viewing this claim as ${user.role.displayNameEn}. Current action is assigned to ${_currentClaim.assignedAuthority.displayNameEn}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // 1. Village Stage Action
        if (_currentClaim.status == ClaimStatus.draft)
          _buildVillageActionCard(user),

        // 2. FRC Findings Action
        if (_currentClaim.status == ClaimStatus.submittedToFrc ||
            _currentClaim.status == ClaimStatus.frcReview)
          _buildFrcActionCard(user),

        // 3. Gram Sabha Resolution Action
        if (_currentClaim.status == ClaimStatus.gramSabhaReview)
          _buildGramSabhaActionCard(user),

        // 4. Field Verification Action
        if (_currentClaim.status == ClaimStatus.gramSabhaApproved ||
            _currentClaim.status == ClaimStatus.fieldVerificationPending ||
            _currentClaim.status == ClaimStatus.fieldVerificationInProgress)
          _buildFieldVerificationActionCard(user),

        // 5. SDLC Review Action
        if (_currentClaim.status == ClaimStatus.fieldVerificationCompleted ||
            _currentClaim.status == ClaimStatus.sdlcReview)
          _buildSdlcActionCard(user),

        // 6. DLC Final Order Action
        if (_currentClaim.status == ClaimStatus.forwardedToDlc ||
            _currentClaim.status == ClaimStatus.dlcReview)
          _buildDlcActionCard(user),

        // 7. Annexure IV Title Signature Action
        if (_currentClaim.status == ClaimStatus.dlcApproved ||
            _currentClaim.status == ClaimStatus.annexureIvPendingDfo ||
            _currentClaim.status ==
                ClaimStatus.annexureIvPendingTribalWelfare ||
            _currentClaim.status == ClaimStatus.annexureIvPendingCollector)
          _buildAnnexureIVActionCard(user),

        // 8. Record Incorporation Action
        if (_currentClaim.status == ClaimStatus.recordIncorporationPending)
          _buildRecordIncorporationActionCard(user),

        // Completed / Read-only state
        if (_currentClaim.status == ClaimStatus.completed)
          Card(
            color: AppColors.successGreen.withOpacity(0.1),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.successGreen, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This CFR Claim workflow is fully completed and title is officially incorporated into government land records.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVillageActionCard(user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit Claim to FRC',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
                'Submit this draft claim to the Forest Rights Committee (FRC) for customary boundary delineation and investigation.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final res = _workflowService.submitToFrc(_currentClaim, user);
                _updateClaim(res);
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Submit to FRC'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestCanopy,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrcActionCard(user) {
    final remarkController = TextEditingController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FRC Investigation & Findings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: 'Customary Boundary & FRC Findings Remarks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final findings = FrcFindings(
                  customaryBoundaryDescription:
                      'Boundaries verified with elders & bordering village reps.',
                  borderingVillages: const ['साखरे (Sakhare)', 'जव्हार (Jawhar)'],
                  frcRemarks: remarkController.text.trim().isEmpty
                      ? 'FRC completed boundary delineation and verified evidence.'
                      : remarkController.text.trim(),
                  submittedAt: DateTime.now(),
                );
                final res = _workflowService.submitFrcFindings(
                    _currentClaim, user, findings);
                _updateClaim(res);
              },
              icon: const Icon(Icons.how_to_reg_rounded),
              label: const Text('Submit Findings to Gram Sabha'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestCanopy,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGramSabhaActionCard(user) {
    final resolutionNoController =
        TextEditingController(text: 'GS-RES-2026-004');
    final notesController = TextEditingController(
        text: 'Unanimously approved with 72% quorum attendance.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gram Sabha Review & Resolution',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: resolutionNoController,
              decoration: const InputDecoration(
                labelText: 'Gram Sabha Resolution Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Meeting Discussion Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final review = GramSabhaReviewData(
                        meetingDate: DateTime.now(),
                        meetingLocation: 'Ozhar Gram Panchayat Hall',
                        resolutionNumber: resolutionNoController.text,
                        resolutionResult: 'APPROVED',
                        discussionNotes: notesController.text,
                        recordedAt: DateTime.now(),
                      );
                      final res = _workflowService.recordGramSabhaResolution(
                          _currentClaim, user, review);
                      _updateClaim(res);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestCanopy,
                        foregroundColor: Colors.white),
                    child: const Text('Approve Resolution'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final review = GramSabhaReviewData(
                        meetingDate: DateTime.now(),
                        meetingLocation: 'Ozhar Gram Panchayat Hall',
                        resolutionNumber: resolutionNoController.text,
                        resolutionResult: 'RETURNED_FOR_CORRECTION',
                        discussionNotes: 'Returned for boundary clarification.',
                        recordedAt: DateTime.now(),
                      );
                      final res = _workflowService.recordGramSabhaResolution(
                          _currentClaim, user, review);
                      _updateClaim(res);
                    },
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red)),
                    child: const Text('Return for Correction'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldVerificationActionCard(user) {
    final obsController = TextEditingController(
        text: 'Joint site inspection completed. Boundaries verified.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Joint Field Verification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_currentClaim.status == ClaimStatus.gramSabhaApproved) ...[
              ElevatedButton.icon(
                onPressed: () {
                  final res = _workflowService.forwardToFieldVerification(
                      _currentClaim, user);
                  _updateClaim(res);
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Initiate Field Verification'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestCanopy,
                    foregroundColor: Colors.white),
              ),
            ] else ...[
              TextField(
                controller: obsController,
                decoration: const InputDecoration(
                  labelText: 'Field Verification Observations',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final rec = FieldVerificationRecord(
                          department: 'forest',
                          officerId: user.id,
                          officerName: user.name,
                          officerDesignation: 'Forest Range Officer',
                          visitDate: DateTime.now(),
                          observations: obsController.text,
                          verificationStatus: 'COMPLETED',
                          submittedAt: DateTime.now(),
                        );
                        final res = _workflowService.submitFieldVerification(
                            _currentClaim, user, rec);
                        _updateClaim(res);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestCanopy,
                          foregroundColor: Colors.white),
                      child: const Text('Submit Forest Verification'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final rec = FieldVerificationRecord(
                          department: 'revenue',
                          officerId: user.id,
                          officerName: user.name,
                          officerDesignation: 'Circle Officer / Tehsildar',
                          visitDate: DateTime.now(),
                          observations: obsController.text,
                          verificationStatus: 'COMPLETED',
                          submittedAt: DateTime.now(),
                        );
                        final res = _workflowService.submitFieldVerification(
                            _currentClaim, user, rec);
                        _updateClaim(res);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.govtBlue,
                          foregroundColor: Colors.white),
                      child: const Text('Submit Revenue Verification'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSdlcActionCard(user) {
    final obsController =
        TextEditingController(text: 'SDLC verified Gram Sabha & Field reports.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sub-Divisional Level Committee (SDLC) Review',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: obsController,
              decoration: const InputDecoration(
                labelText: 'SDLC Observations & Draft Record',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final sdlcData = SdlcReviewData(
                  reviewDate: DateTime.now(),
                  officerName: user.name,
                  observations: obsController.text,
                  draftRecordDetails: 'Draft Title Record V1 Consolidated.',
                  decision: 'APPROVED',
                  submittedAt: DateTime.now(),
                );
                final res = _workflowService.submitSdlcReview(
                    _currentClaim, user, sdlcData);
                _updateClaim(res);
              },
              icon: const Icon(Icons.forward_to_inbox_rounded),
              label: const Text('Approve & Forward to DLC'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestCanopy,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDlcActionCard(user) {
    final remarksController = TextEditingController();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('District Level Committee (DLC) Final Order',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'DLC Order Remarks / Reason (Mandatory)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final dlcData = DlcDecisionData(
                      decisionType: 'dlcApproved',
                      decisionDate: DateTime.now(),
                      remarks: remarksController.text.trim().isEmpty
                          ? 'DLC Approved after examining all evidence.'
                          : remarksController.text,
                      officerName: user.name,
                    );
                    final res = _workflowService.recordDlcDecision(
                        _currentClaim, user, dlcData);
                    _updateClaim(res);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestCanopy,
                      foregroundColor: Colors.white),
                  child: const Text('Approve DLC Title'),
                ),
                OutlinedButton(
                  onPressed: () {
                    final dlcData = DlcDecisionData(
                      decisionType: 'dlcRemanded',
                      decisionDate: DateTime.now(),
                      remarks: remarksController.text.trim().isEmpty
                          ? 'Remanded to SDLC for map re-verification.'
                          : remarksController.text,
                      officerName: user.name,
                    );
                    final res = _workflowService.recordDlcDecision(
                        _currentClaim, user, dlcData);
                    _updateClaim(res);
                  },
                  child: const Text('Remand to SDLC'),
                ),
                OutlinedButton(
                  onPressed: () {
                    final dlcData = DlcDecisionData(
                      decisionType: 'dlcRejected',
                      decisionDate: DateTime.now(),
                      remarks: remarksController.text.trim().isEmpty
                          ? 'Rejected due to lack of pre-2005 evidence.'
                          : remarksController.text,
                      officerName: user.name,
                    );
                    final res = _workflowService.recordDlcDecision(
                        _currentClaim, user, dlcData);
                    _updateClaim(res);
                  },
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red)),
                  child: const Text('Reject Claim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnexureIVActionCard(user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Annexure IV Title Digital Signatures',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Required 3 Signatories: DFO → District Tribal Welfare Officer → District Collector',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final res = await _workflowService.signAnnexureIV(
                  _currentClaim,
                  user,
                  notes: 'Digital signature recorded for Annexure IV Title.',
                );
                _updateClaim(res);
              },
              icon: const Icon(Icons.draw_rounded),
              label: Text('Sign Annexure IV as ${user.role.displayNameEn}'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.saffron,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordIncorporationActionCard(user) {
    final revController =
        TextEditingController(text: 'REV-PALGHAR-2026-9921');
    final forController =
        TextEditingController(text: 'FOR-JAWHAR-2026-1102');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Incorporation in Land Registers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: revController,
              decoration: const InputDecoration(
                labelText: 'Revenue Land Record Reference Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: forController,
              decoration: const InputDecoration(
                labelText: 'Forest Register Reference Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                final rec = RecordIncorporationData(
                  revenueRecordNumber: revController.text,
                  forestRecordNumber: forController.text,
                  incorporationDate: DateTime.now(),
                  recordOfficerName: user.name,
                  remarks:
                      'Official land record incorporation complete in 7/12 & Forest Register.',
                );
                final res = _workflowService.completeRecordIncorporation(
                    _currentClaim, user, rec);
                _updateClaim(res);
              },
              icon: const Icon(Icons.inventory_rounded),
              label: const Text('Confirm Land Record Incorporation'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestCanopy,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogTab(BuildContext context) {
    final trail = _currentClaim.auditTrail;

    if (trail.isEmpty) {
      return const Center(child: Text('No audit history logged yet.'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: trail.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final event = trail[index];
        return Card(
          elevation: 1,
          child: ListTile(
            leading: const Icon(Icons.history_edu_rounded,
                color: AppColors.forestCanopy),
            title: Text(
              event.action,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.comment, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  'By: ${event.actorRole.displayNameEn} • ${DateFormat('dd MMM yyyy, hh:mm a').format(event.timestamp)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
