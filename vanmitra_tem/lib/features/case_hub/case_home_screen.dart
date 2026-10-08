// Case Stepper Dashboard (Module 1 & Module 2): 6-Step Statutory Journey

import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/deadline_banner.dart';
import '../../shared/widgets/step_card.dart';
import '../form_a/form_a_screen.dart';
import '../form_b/form_b_screen.dart';
import '../form_c/form_c_screen.dart';
import 'case_hub_api.dart';

class CaseHomeScreen extends StatefulWidget {
  final String caseId;
  final String? initialClaimType;

  const CaseHomeScreen({
    super.key,
    required this.caseId,
    this.initialClaimType,
  });

  @override
  State<CaseHomeScreen> createState() => _CaseHomeScreenState();
}

class _CaseHomeScreenState extends State<CaseHomeScreen> {
  final CaseHubApi _api = CaseHubApi();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _caseData;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadCase();
  }

  Future<void> _loadCase() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getCaseDetails(widget.caseId);
      if (mounted) {
        setState(() {
          _caseData = data;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _openClaimForm() async {
    if (_caseData == null) return;
    final claimType = _caseData!['claim_type'] as String? ?? widget.initialClaimType ?? 'ifr';
    final state = _caseData!['state'] as String? ?? 'draft';
    final isEditable = state == 'draft';

    Widget targetScreen;
    if (claimType == 'ifr') {
      targetScreen = FormAScreen(caseId: widget.caseId, canEdit: isEditable);
    } else if (claimType == 'cr') {
      targetScreen = FormBScreen(caseId: widget.caseId, canEdit: isEditable);
    } else {
      targetScreen = FormCScreen(caseId: widget.caseId, canEdit: isEditable);
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => targetScreen),
    );

    // Refresh case status upon returning
    _loadCase();
  }

  Future<void> _handleSubmit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Claim / दावा दाखल करा'),
        content: const Text(
          'Are you sure you want to submit this claim to the Gram Sabha? The form will be locked for review.\n\nतुम्ही हा दावा ग्रामसभेकडे दाखल करू इच्छिता का?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit / दाखल करा'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      await _api.submitCase(widget.caseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim submitted to Gram Sabha successfully!'), backgroundColor: Colors.green),
        );
      }
      _loadCase();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.error}: ${e.messageKey} ${e.rule != null ? "[${e.rule}]" : ""}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleApprove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Forward / मंजूर करा'),
        content: const Text(
          'Approve this claim and forward to the next statutory stage?\n\nहा दावा मंजूर करून पुढील स्तरावर पाठवायचा का?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve / मंजूर करा'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      await _api.approveCase(widget.caseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim approved successfully!'), backgroundColor: Colors.green),
        );
      }
      _loadCase();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.error}: ${e.messageKey} ${e.rule != null ? "[${e.rule}]" : ""}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleReturn() async {
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Claim with Remarks / त्रुटींसाठी परत पाठवा'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the specific corrections required. Under Rule 12A(7), the claimant receives 60 days to fix and resubmit.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Remarks / त्रुटींचे विवरण (min 5 chars) *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
            onPressed: () {
              if (remarksCtrl.text.trim().length >= 5) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Return / परत पाठवा'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _actionInProgress = true);
    try {
      await _api.returnCase(widget.caseId, remarksCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim returned with remarks.'), backgroundColor: Colors.amber),
        );
      }
      _loadCase();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.error}: ${e.messageKey}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _handleReject() async {
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Claim / दावा नाकारणे (Rule 12A(7))'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Under Rule 12A(7), a claim cannot be rejected without recording written legal reasons in detail.',
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Written Statutory Reasons / कायदेशीर कारणे *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            onPressed: () {
              if (remarksCtrl.text.trim().length >= 10) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reject with Reasons / नाकारा'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _actionInProgress = true);
    try {
      await _api.rejectCase(widget.caseId, remarksCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim marked rejected with statutory reasons.'), backgroundColor: Colors.red),
        );
      }
      _loadCase();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.error}: ${e.messageKey}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _caseData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading case: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadCase, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final data = _caseData!;
    final claimType = (data['claim_type'] as String? ?? 'ifr').toUpperCase();
    final formLetter = data['form'] as String? ?? (claimType == 'IFR' ? 'A' : (claimType == 'CR' ? 'B' : 'C'));
    final state = data['state'] as String? ?? 'draft';
    final claimantLabel = data['claimant_label'] as String? ?? 'Claimant';
    final village = data['village_name_mr'] ?? data['village_name_en'] ?? '';
    final taluka = data['taluka'] ?? '';
    final allowedActions = (data['allowed_actions'] as List<dynamic>? ?? []).cast<String>();
    final returned = data['returned'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text('$claimType Claim — Form $formLetter'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCase),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(allowedActions),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Case Overview Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Form $formLetter · $claimType',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStateColor(state),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatStateLabel(state),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    claimantLabel,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Village: $village · Taluka: $taluka',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Return Deadline Banner if returned
          if (returned != null)
            DeadlineBanner(
              remarks: returned['remarks'] ?? '',
              daysLeft: returned['days_left'] as int? ?? 60,
              returnedByName: returned['by_name'] as String?,
              returnedByRole: returned['by_role'] as String?,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'वैधानिक प्रक्रिया टप्पे / 6-Step Statutory Journey',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),

          // Step 1: Claim Form
          StepCard(
            stepNumber: 1,
            title: 'दावा अर्ज / Form $formLetter Claim Details',
            subtitle: 'Statutory claim form, personal details, claims and family members',
            status: state == 'draft' ? StepStatus.inProgress : StepStatus.completed,
            onTap: _openClaimForm,
          ),

          // Step 2: Evidence Pool
          StepCard(
            stepNumber: 2,
            title: 'पुरावा संच / Evidence Pool (Rule 13)',
            subtitle: 'Photos, PDFs, and Elder Voice Recordings',
            status: state == 'draft' ? StepStatus.pending : StepStatus.inProgress,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Module 5 (Evidence Pool) integration available in Evidence step')),
              );
            },
          ),

          // Step 3: Boundary & Landmarks
          StepCard(
            stepNumber: 3,
            title: 'सीमांकन आणि चतुःसीमा / Boundary & Mapping',
            subtitle: 'GPS perimeter walk, landmarks, and traditional use zones',
            status: StepStatus.pending,
            onTap: () {},
          ),

          // Step 4: Field Verification
          StepCard(
            stepNumber: 4,
            title: 'क्षेत्रीय पडताळणी / Joint Field Verification',
            subtitle: 'Joint inspection by Revenue, Forest and FRC',
            status: StepStatus.pending,
            onTap: () {},
          ),

          // Step 5: Gram Sabha Meeting
          StepCard(
            stepNumber: 5,
            title: 'ग्रामसभा ठराव / Gram Sabha Meeting & Resolution',
            subtitle: 'Meeting quorum, member attendance and formal resolution',
            status: StepStatus.pending,
            onTap: () {},
          ),

          // Step 6: Status & Title Certificate
          StepCard(
            stepNumber: 6,
            title: 'अंतिम सनद / Title Certificate & Orders',
            subtitle: 'SDO / DLC approval and statutory Annexure title draft',
            status: state == 'title_issued' ? StepStatus.completed : StepStatus.pending,
            onTap: () {},
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget? _buildBottomActionBar(List<String> allowedActions) {
    if (allowedActions.isEmpty) return null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            if (allowedActions.contains('reject')) ...[
              OutlinedButton(
                onPressed: _actionInProgress ? null : _handleReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  side: BorderSide(color: Colors.red.shade800),
                ),
                child: const Text('Reject / नाकारा'),
              ),
              const SizedBox(width: 8),
            ],
            if (allowedActions.contains('return')) ...[
              ElevatedButton(
                onPressed: _actionInProgress ? null : _handleReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Return / परत'),
              ),
              const SizedBox(width: 8),
            ],
            if (allowedActions.contains('submit')) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _actionInProgress ? null : _handleSubmit,
                  icon: const Icon(Icons.send),
                  label: const Text('दाखल करा / Submit Claim', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
            if (allowedActions.contains('approve')) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _actionInProgress ? null : _handleApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('मंजूर करा / Approve & Forward', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'draft':
        return Colors.orange.shade700;
      case 'gs_review':
        return Colors.blue.shade700;
      case 'sdo_review':
        return Colors.purple.shade700;
      case 'district_review':
        return Colors.indigo.shade700;
      case 'title_issued':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatStateLabel(String state) {
    switch (state) {
      case 'draft':
        return 'DRAFT / मसुदा';
      case 'gs_review':
        return 'GRAM SABHA REVIEW';
      case 'sdo_review':
        return 'SDO REVIEW';
      case 'district_review':
        return 'DISTRICT REVIEW';
      case 'title_issued':
        return 'TITLE ISSUED / सनद प्राप्त';
      case 'rejected':
        return 'REJECTED / नाकारले';
      default:
        return state.toUpperCase();
    }
  }
}
