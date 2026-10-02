import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../models/claim.dart';
import '../../providers/claims_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/status_timeline_widget.dart';
import '../../services/localization_service.dart';

/// 5-step claim form wizard — DBT application style with save-and-resume.
///
/// Steps: ① दावेदार माहिती → ② जमीन तपशील → ③ ताबा तपशील → ④ पुरावा → ⑤ पुनरावलोकन
///
/// Each step is a separate view within the same screen (not separate routes).
/// "Save Draft" persists to Hive at every step — works offline.
class ClaimFormScreen extends ConsumerStatefulWidget {
  const ClaimFormScreen({super.key});

  @override
  ConsumerState<ClaimFormScreen> createState() => _ClaimFormScreenState();
}

class _ClaimFormScreenState extends ConsumerState<ClaimFormScreen> {
  int _currentStep = 0;
  ClaimType _claimType = ClaimType.formA;

  // Step 1 — Claimant info
  final _nameCtrl = TextEditingController();
  final _fatherCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Step 2 — Land details
  final _surveyCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  ClaimNature _nature = ClaimNature.cultivation;

  // Step 3 — Occupation details
  final _yearsCtrl = TextEditingController();
  bool _before2005 = true;
  final _descCtrl = TextEditingController();

  // Step 4 — Evidence (handled by EvidenceChecklistScreen)
  // Step 5 — Review (handled by DraftPreviewScreen)

  String? _draftClaimId;
  bool _isSaving = false;

  List<String> _stepLabels(BuildContext context) => [
    context.tr('step_1_claimant'),
    context.tr('step_2_land'),
    context.tr('step_3_occupancy'),
    context.tr('step_4_evidence'),
    context.tr('step_5_review'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ClaimType) {
      _claimType = args;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fatherCtrl.dispose();
    _addressCtrl.dispose();
    _surveyCtrl.dispose();
    _areaCtrl.dispose();
    _yearsCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    final auth = ref.read(authProvider);
    final userId = auth.currentUser?.id ?? 'unknown';
    final villageId = auth.currentUser?.villageId ?? 'ozhar_01';

    final claimId = _draftClaimId ?? const Uuid().v4();
    _draftClaimId = claimId;

    final claim = Claim(
      id: claimId,
      claimantUserId: userId,
      villageId: villageId,
      type: _claimType,
      status: ClaimStatus.draft,
      nature: _nature,
      claimantName: _nameCtrl.text.trim(),
      claimantNameEn: _nameCtrl.text.trim(),
      fatherHusbandName: _fatherCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      surveyNumber: _surveyCtrl.text.trim(),
      areaSqMeters: double.tryParse(_areaCtrl.text) ?? 0.0,
      landDescription: _descCtrl.text.trim(),
      occupationYears: int.tryParse(_yearsCtrl.text) ?? 0,
      occupationBefore2005: _before2005,
      evidenceFlags: const {},
      evidenceScore: 0.0,
      missingEvidence: const [],
      createdAt: DateTime.now(),
    );

    await ref.read(claimsProvider.notifier).addClaim(claim);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('draft_saved'),
            style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_nameCtrl.text.trim().isEmpty ||
          _fatherCtrl.text.trim().isEmpty ||
          _addressCtrl.text.trim().isEmpty) {
        _showEmptyFieldAlert(
            'Claimant Details (Name, Father/Husband Name, Address)');
        return false;
      }
    } else if (step == 1) {
      if (_surveyCtrl.text.trim().isEmpty ||
          _areaCtrl.text.trim().isEmpty) {
        _showEmptyFieldAlert(
            'Land Details (Survey/Gat Number, Area Claimed)');
        return false;
      }
    } else if (step == 2) {
      if (_yearsCtrl.text.trim().isEmpty) {
        _showEmptyFieldAlert('Occupancy Details (Period of Occupation)');
        return false;
      }
    }
    return true;
  }

  void _showEmptyFieldAlert(String stepName) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.alertRed, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Required Fields Empty! / माहिती अपूर्ण!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.alertRed,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.alertRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.alertRed.withOpacity(0.3)),
              ),
              child: Text(
                '⚠️ Please fill in all required information for $stepName before proceeding to the next step.',
                style: TextStyle(fontSize: 12, height: 1.4, color: c.textPrimary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'कृपया पुढील टप्प्यावर जाण्यापूर्वी सर्व आवश्यक माहिती भरा.',
              style: TextStyle(
                fontSize: 11,
                color: c.textSecondary,
                fontFamily: 'NotoSansDevanagari',
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK / समजले'),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < 4) {
      _saveDraft();
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
    final formTypeLocalized = _claimType == ClaimType.formA
        ? context.tr('form_a_title')
        : context.tr('form_b_title');

    return PortalFrameScaffold(
      breadcrumbs: [context.tr('tab_dashboard'), context.tr('claims'), context.tr('action_new_claim'), formTypeLocalized],
      body: Column(
        children: [
          // ── Step Timeline ────────────────────────────────────────────────
          StatusTimelineWidget(
            steps: _stepLabels(context),
            currentStep: _currentStep,
          ),
          const Divider(height: 1),

          // ── Step Content ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCurrentStep(),
            ),
          ),

          // ── Navigation Buttons ───────────────────────────────────────────
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4Placeholder();
      case 4:
        return _buildStep5Placeholder();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Claimant Info ──────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('section_claimant_info')),
        const SizedBox(height: 16),
        _dbtField(
          controller: _nameCtrl,
          label: context.tr('label_claimant_name'),
          hint: context.tr('hint_claimant_name'),
        ),
        const SizedBox(height: 12),
        _dbtField(
          controller: _fatherCtrl,
          label: context.tr('label_father_name'),
          hint: context.tr('hint_father_name'),
        ),
        const SizedBox(height: 12),
        _dbtField(
          controller: _addressCtrl,
          label: context.tr('label_address'),
          hint: context.tr('hint_address'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        _infoBox(context.tr('info_auto_fill')),
      ],
    );
  }

  // ── Step 2: Land Details ──────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('section_land_details')),
        const SizedBox(height: 16),
        _dbtField(
          controller: _surveyCtrl,
          label: context.tr('label_survey_no'),
          hint: context.tr('hint_survey_no'),
        ),
        const SizedBox(height: 12),
        _dbtField(
          controller: _areaCtrl,
          label: context.tr('label_area'),
          hint: context.tr('hint_area'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('label_nature_of_claim'),
          style: const TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...ClaimNature.values.map((n) => RadioListTile<ClaimNature>(
              value: n,
              groupValue: _nature,
              onChanged: (v) => setState(() => _nature = v!),
              title: Text(
                n.displayNameMr,
                style: const TextStyle(
                  fontFamily: 'NotoSansDevanagari',
                  fontSize: 13,
                ),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.govtBlue,
            )),
      ],
    );
  }

  // ── Step 3: Occupation Details ────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context.tr('section_occupancy_details')),
        const SizedBox(height: 16),
        _dbtField(
          controller: _yearsCtrl,
          label: context.tr('label_years_occupied'),
          hint: context.tr('hint_years_occupied'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _before2005,
          onChanged: (v) => setState(() => _before2005 = v!),
          title: Text(
            context.tr('label_before_2005'),
            style: const TextStyle(
              fontFamily: 'NotoSansDevanagari',
              fontSize: 13,
            ),
          ),
          activeColor: AppColors.govtBlue,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        _dbtField(
          controller: _descCtrl,
          label: context.tr('label_land_description'),
          hint: context.tr('hint_land_description'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        if (!_before2005)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.alertRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.alertRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.alertRed, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('fra_2005_warning'),
                    style: const TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 11,
                      color: AppColors.alertRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Step 4: Evidence → navigate to EvidenceChecklistScreen ───────────────

  Widget _buildStep4Placeholder() {
    return Column(
      children: [
        _sectionTitle(context.tr('section_upload_evidence')),
        const SizedBox(height: 16),
        Text(
          context.tr('evidence_upload_instruction'),
          style: const TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _saveDraft();
              if (mounted && _draftClaimId != null) {
                await Navigator.pushNamed(
                  context,
                  AppRouter.evidenceChecklist,
                  arguments: _draftClaimId,
                );
              }
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              context.tr('btn_go_to_evidence'),
              style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.govtBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 5: Review → navigate to DraftPreviewScreen ──────────────────────

  Widget _buildStep5Placeholder() {
    return Column(
      children: [
        _sectionTitle(context.tr('section_review_submit')),
        const SizedBox(height: 16),
        Text(
          context.tr('review_submit_desc'),
          style: const TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_draftClaimId != null) {
                Navigator.pushNamed(
                  context,
                  AppRouter.claimDraft,
                  arguments: _draftClaimId,
                );
              }
            },
            icon: const Icon(Icons.preview_rounded),
            label: Text(
              context.tr('btn_preview_draft'),
              style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentSaffron,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Navigation bar ────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: c.isDark
            ? []
            : const [
                BoxShadow(
                    color: Color(0x15000000),
                    blurRadius: 8,
                    offset: Offset(0, -2))
              ],
      ),
      child: Row(
        children: [
          // Save Draft
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _saveDraft,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt_rounded, size: 16),
            label: Text(
              context.tr('btn_save'),
              style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
              side: BorderSide(color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const Spacer(),

          // Back
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                context.tr('btn_back'),
                style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
              ),
              style: TextButton.styleFrom(
                  foregroundColor: c.textSecondary),
            ),

          const SizedBox(width: 8),

          // Next
          if (_currentStep < 4)
            ElevatedButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                context.tr('btn_next'),
                style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Divider(
          color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
          thickness: 1.5,
        ),
      ],
    );
  }

  Widget _dbtField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final c = context.colors;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'This information is required / ही माहिती आवश्यक आहे';
        }
        return null;
      },
      style: TextStyle(
        fontFamily: 'NotoSansDevanagari',
        fontSize: 14,
        color: c.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: c.isDark,
        fillColor: c.isDark ? c.sunkenBg : null,
        labelStyle: TextStyle(
          fontFamily: 'NotoSansDevanagari',
          fontSize: 12,
          color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
        ),
        hintStyle: TextStyle(
          fontFamily: 'NotoSansDevanagari',
          fontSize: 12,
          color: c.textTertiary,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.alertRed, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _infoBox(String text) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: c.isDark ? c.border : AppColors.govtBlue.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'NotoSansDevanagari',
                fontSize: 11,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
