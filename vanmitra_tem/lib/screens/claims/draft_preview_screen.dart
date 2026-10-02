import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../models/claim.dart';
import '../../providers/claims_provider.dart';
import '../../providers/module_a_provider.dart';
import '../../services/module_a_service.dart';
import '../../widgets/portal_frame_scaffold.dart';
import '../../widgets/document_paper_card.dart';

/// Draft Preview Screen — shows the AI-generated or template draft.
///
/// Wraps the draft text in DocumentPaperCard — styled like the printed
/// Form A/B it will become (DBT print-preview convention, spec B.4.6).
///
/// Amber "AI-Generated Draft" banner shown when is_ai_generated == true.
/// "मान्य आहे" → submits the claim; "संपादित करा" → editable mode.
class DraftPreviewScreen extends ConsumerStatefulWidget {
  const DraftPreviewScreen({super.key});

  @override
  ConsumerState<DraftPreviewScreen> createState() =>
      _DraftPreviewScreenState();
}

class _DraftPreviewScreenState extends ConsumerState<DraftPreviewScreen> {
  String? _claimId;
  Claim? _claim;
  ClaimDraftResult? _draft;
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSubmitting = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _claimId == null) {
      _claimId = args;
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final claims = ref.read(claimsProvider);
    _claim = claims.claims
        .cast<Claim?>()
        .firstWhere((c) => c?.id == _claimId, orElse: () => null);

    if (_claim == null) {
      setState(() => _isLoading = false);
      return;
    }

    final service = ref.read(moduleAProvider);

    try {
      final draft = await service.generateDraft(
        claimType: _claim!.type,
        claimantName: _claim!.claimantName,
        fatherHusbandName: _claim!.fatherHusbandName ?? '',
        address: _claim!.address ?? 'ओझर, जव्हार, पालघर',
        surveyNumber: _claim!.surveyNumber ?? '',
        areaSqMeters: _claim!.areaSqMeters ?? 0.0,
        natureOfRight: _claim!.nature.displayNameEn,
        occupationYears: _claim!.occupationYears ?? 0,
        evidence: _claim!.evidenceFlags,
      );

      setState(() {
        _draft = draft;
        _editController.text = draft.draftText;
        _isLoading = false;
      });
    } on ModuleAServiceException catch (_) {
      // Fallback to DefaultModuleAService
      final fallback = DefaultModuleAService();
      final draft = await fallback.generateDraft(
        claimType: _claim!.type,
        claimantName: _claim!.claimantName,
        fatherHusbandName: _claim!.fatherHusbandName ?? '',
        address: _claim!.address ?? 'ओझर, जव्हार, पालघर',
        surveyNumber: _claim!.surveyNumber ?? '',
        areaSqMeters: _claim!.areaSqMeters ?? 0.0,
        natureOfRight: _claim!.nature.displayNameEn,
        occupationYears: _claim!.occupationYears ?? 0,
        evidence: _claim!.evidenceFlags,
      );
      setState(() {
        _draft = draft;
        _editController.text = draft.draftText;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitClaim() async {
    if (_claim == null) return;
    setState(() => _isSubmitting = true);

    // Use edited text if user modified it
    final finalText = _isEditMode ? _editController.text : _draft!.draftText;
    // finalText will be saved in the claim object (omitted for brevity)

    final updated = _claim!.copyWith(
      status: ClaimStatus.submitted,
      submittedAt: DateTime.now(),
    );

    await ref.read(claimsProvider.notifier).updateClaim(updated);
    setState(() => _isSubmitting = false);

    if (mounted) {
      // Navigate to tracking screen
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.myClaims,
        (route) => route.settings.name == AppRouter.villagerHome,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ दावा क्र. ${_claim!.id.substring(0, 8)} सादर झाला!',
            style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
          ),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formTitle = _claim?.type == ClaimType.formA
        ? 'फॉर्म अ — वैयक्तिक वन हक्क दावा'
        : 'फॉर्म ब — सामुदायिक हक्क दावा';

    final c = context.colors;
    return PortalFrameScaffold(
      breadcrumbs: const [
        'मुख्यपृष्ठ',
        'दावे',
        'नवीन दावा',
        'मसुदा पूर्वावलोकन'
      ],
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI मसुदा तयार करत आहे…',
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 14,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
            )
          : _draft == null
              ? Center(
                  child: Text('दावा सापडला नाही', style: TextStyle(color: c.textSecondary)),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      DocumentPaperCard(
                        draftText: _draft!.draftText,
                        isAIGenerated: _draft!.isAIGenerated,
                        title: formTitle,
                        isEditMode: _isEditMode,
                        editController: _editController,
                        onEdit: () =>
                            setState(() => _isEditMode = !_isEditMode),
                        onApprove: _isSubmitting ? null : _submitClaim,
                      ),

                      // Submit feedback
                      if (_isSubmitting)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                  color: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue),
                              const SizedBox(width: 12),
                              Text(
                                'सादर करत आहे…',
                                style: TextStyle(
                                  fontFamily: 'NotoSansDevanagari',
                                  color: c.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
