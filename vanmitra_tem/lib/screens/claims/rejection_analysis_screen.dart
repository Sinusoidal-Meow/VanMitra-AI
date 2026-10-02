import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_router.dart';
import '../../models/claim.dart';
import '../../providers/claims_provider.dart';
import '../../providers/module_a_provider.dart';
import '../../services/module_a_service.dart';
import '../../widgets/portal_frame_scaffold.dart';

/// Rejection Analysis Screen — uploads rejection order photo for OCR+AI analysis.
///
/// Calls RejectionAgent via FastAPI /api/v1/analyze-rejection.
/// Shows classification result (rejection reason + validity assessment).
/// One-tap → Appeal Draft screen.
class RejectionAnalysisScreen extends ConsumerStatefulWidget {
  const RejectionAnalysisScreen({super.key});

  @override
  ConsumerState<RejectionAnalysisScreen> createState() =>
      _RejectionAnalysisScreenState();
}

class _RejectionAnalysisScreenState
    extends ConsumerState<RejectionAnalysisScreen> {
  String? _claimId;
  Claim? _claim;
  RejectionAnalysis? _analysis;
  bool _isAnalyzing = false;
  String? _imagePath;

  final _picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && _claimId == null) {
      _claimId = args;
      _loadClaim();
    }
  }

  void _loadClaim() {
    final claims = ref.read(claimsProvider);
    setState(() {
      _claim = claims.claims
          .cast<Claim?>()
          .firstWhere((c) => c?.id == _claimId, orElse: () => null);
    });
  }

  Future<ImageSource?> _showSourcePicker(BuildContext context) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Document Source / स्त्रोत निवडा',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.forestCanopy,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.forestCanopy),
              ),
              title: const Text('Take Photo / कॅमेरा'),
              subtitle: const Text('Capture rejection order with camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: AppColors.govtBlue),
              ),
              title: const Text('Phone Gallery / गॅलरी'),
              subtitle: const Text('Choose rejection order from phone gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndAnalyze() async {
    final source = await _showSourcePicker(context);
    if (source == null) return;

    final imageFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _imagePath = imageFile.path;
    });

    final service = ref.read(moduleAProvider);

    try {
      final bytes = await imageFile.readAsBytes();
      final analysis = await service.analyzeRejection(bytes);
      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
      });

      // Auto-trigger appeal deadline notice
      if (analysis.appealRecommended && _claim != null) {
        final rejectionDate = analysis.rejectionDate ?? DateTime.now();
        final updatedClaim = _claim!.copyWith(
          status: ClaimStatus.rejected,
          rejectedAt: rejectionDate,
          appealDeadline: rejectionDate.add(const Duration(days: 60)),
          rejectionReason: analysis.rejectionReason,
        );
        await ref
            .read(claimsProvider.notifier)
            .updateClaim(updatedClaim);
        setState(() => _claim = updatedClaim);
      }
    } on ModuleAServiceException catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ऑफलाइन — विश्लेषण नंतर करा: ${e.message}',
              style: const TextStyle(fontFamily: 'NotoSansDevanagari'),
            ),
            backgroundColor: AppColors.warningAmber,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PortalFrameScaffold(
      breadcrumbs: const [
        'मुख्यपृष्ठ',
        'माझे दावे',
        'नामंजुरी विश्लेषण'
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.isDark
                    ? AppColors.alertRed.withOpacity(0.12)
                    : AppColors.alertRed.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.alertRed.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel_rounded,
                          color: AppColors.alertRed, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'नामंजुरी आदेश विश्लेषण',
                        style: TextStyle(
                          fontFamily: 'NotoSansDevanagari',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.alertRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _claim != null
                        ? 'दावेदार: ${_claim!.claimantName} (${_claim!.id.substring(0, 12)}…)'
                        : 'नामंजुरी आदेशाचा फोटो काढा, AI नामंजुरीचे कारण ओळखेल.',
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 12,
                      color: c.isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'अपील मुदत: नामंजुरी आदेशापासून 60 दिवस (FRA Sec. 6)',
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 11,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Upload Order button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _captureAndAnalyze,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.alertRed,
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(
                  _isAnalyzing
                      ? 'AI विश्लेषण करत आहे…'
                      : 'नामंजुरी आदेशाचा फोटो काढा',
                  style: const TextStyle(
                      fontFamily: 'NotoSansDevanagari'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.alertRed,
                  side: const BorderSide(color: AppColors.alertRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),

            // ── Analysis result ──────────────────────────────────────────
            if (_analysis != null) ...[
              const SizedBox(height: 24),
              _buildAnalysisResult(context),
            ],

            if (_analysis == null && !_isAnalyzing) ...[
              const SizedBox(height: 24),
              Text(
                'किंवा नामंजुरीचे कारण मॅन्युअली प्रविष्ट करा:',
                style: TextStyle(
                  fontFamily: 'NotoSansDevanagari',
                  fontSize: 12,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _ManualRejectionForm(
                onSubmit: (reason) {
                  setState(() {
                    _analysis = RejectionAnalysis(
                      isOCRProcessed: false,
                      rejectionReason: reason,
                      validityExplanation:
                          'Manual entry — appeal recommended.',
                      appealRecommended: true,
                    );
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult(BuildContext context) {
    final c = context.colors;
    final analysis = _analysis!;
    final color = analysis.appealRecommended
        ? AppColors.accentSaffron
        : AppColors.alertRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI विश्लेषण परिणाम',
          style: TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Rejection reason card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(c.isDark ? 0.6 : 0.4)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(c.isDark ? 0.15 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultRow(
                label: 'नामंजुरीचे कारण',
                value: analysis.rejectionReason ?? 'अज्ञात',
                color: AppColors.alertRed,
              ),
              Divider(color: c.border),
              _ResultRow(
                label: 'नामंजुरी वैध आहे का?',
                value: analysis.isRejectionValid == true
                    ? 'होय'
                    : analysis.isRejectionValid == false
                        ? 'नाही — अपील करा'
                        : 'अनिश्चित',
                color: analysis.isRejectionValid == true
                    ? AppColors.alertRed
                    : AppColors.successGreen,
              ),
              Divider(color: c.border),
              Text(
                analysis.validityExplanation,
                style: TextStyle(
                  fontFamily: 'NotoSansDevanagari',
                  fontSize: 12,
                  color: c.textPrimary,
                  height: 1.6,
                ),
              ),
              if (!analysis.isOCRProcessed) ...[
                const SizedBox(height: 8),
                Text(
                  '* ऑफलाइन मोड — OCR उपलब्ध नाही',
                  style: TextStyle(
                    fontSize: 10,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (analysis.appealRecommended) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRouter.appealDraft,
                arguments: {
                  'claimId': _claimId,
                  'analysis': analysis,
                },
              ),
              icon: const Icon(Icons.gavel_rounded),
              label: const Text(
                'अपील मसुदा तयार करा (Sec. 6)',
                style: TextStyle(fontFamily: 'NotoSansDevanagari'),
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
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ResultRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoSansDevanagari',
                fontSize: 12,
                color: c.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'NotoSansDevanagari',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualRejectionForm extends StatefulWidget {
  final void Function(String reason) onSubmit;
  const _ManualRejectionForm({required this.onSubmit});

  @override
  State<_ManualRejectionForm> createState() =>
      _ManualRejectionFormState();
}

class _ManualRejectionFormState extends State<_ManualRejectionForm> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        TextFormField(
          controller: _ctrl,
          maxLines: 3,
          style: TextStyle(
              fontFamily: 'NotoSansDevanagari', fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'नामंजुरीचे कारण प्रविष्ट करा…',
            hintStyle: TextStyle(
                fontFamily: 'NotoSansDevanagari', fontSize: 12, color: c.textTertiary),
            filled: c.isDark,
            fillColor: c.isDark ? c.sunkenBg : null,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.accentSaffron, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: c.border),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_ctrl.text.trim().isNotEmpty) {
                widget.onSubmit(_ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: c.isDark ? AppColors.accentSaffron : AppColors.govtBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text(
              'सादर करा',
              style: TextStyle(fontFamily: 'NotoSansDevanagari'),
            ),
          ),
        ),
      ],
    );
  }
}
