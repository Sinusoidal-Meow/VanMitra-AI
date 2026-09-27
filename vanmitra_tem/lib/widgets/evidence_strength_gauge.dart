import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../core/theme/app_colors.dart';
import '../services/localization_service.dart';

/// Evidence strength gauge — 🟢/🟡/🔴 arc + per-category table rows.
///
/// Pinned at the top of EvidenceChecklistScreen, updates live as each
/// document row is verified. Driven by ScoringAgent-compatible weight map.
class EvidenceStrengthGauge extends StatelessWidget {
  /// Current evidence score E ∈ [0, 1]
  final double score;

  /// Number of evidence categories present
  final int presentCount;

  /// Total evidence categories
  final int totalCount;

  const EvidenceStrengthGauge({
    super.key,
    required this.score,
    required this.presentCount,
    required this.totalCount,
  });

  Color get _color {
    if (score >= 0.8) return AppColors.successGreen;
    if (score >= 0.6) return AppColors.warningAmber;
    return AppColors.alertRed;
  }

  String _tierLabel(BuildContext context) {
    if (score >= 0.8) return context.tr('evidence_ready');
    if (score >= 0.6) return context.tr('evidence_partial');
    return context.tr('evidence_risk');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Arc gauge ────────────────────────────────────────────────────
          CircularPercentIndicator(
            radius: 44.0,
            lineWidth: 8.0,
            animation: true,
            animationDuration: 600,
            percent: score.clamp(0.0, 1.0),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(score * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
              ],
            ),
            progressColor: _color,
            backgroundColor: _color.withOpacity(0.12),
            circularStrokeCap: CircularStrokeCap.round,
          ),

          const SizedBox(width: 16),

          // ── Text info ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('evidence_score_label'),
                  style: const TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tierLabel(context),
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
                const SizedBox(height: 8),
                // Evidence count bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        totalCount > 0 ? presentCount / totalCount : 0.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(_color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$presentCount/$totalCount ${context.tr('evidence_submitted')}',
                  style: const TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single evidence category table row.
///
/// Shows: category label | weight | status chip | upload button
class EvidenceTableRow extends StatelessWidget {
  final String categoryKey;
  final String categoryLabelMr;
  final double weight;
  final String verificationStatus; // unverified | auto_verified | needs_review | rejected
  final bool isUploading;
  final VoidCallback onUpload;

  const EvidenceTableRow({
    super.key,
    required this.categoryKey,
    required this.categoryLabelMr,
    required this.weight,
    required this.verificationStatus,
    required this.isUploading,
    required this.onUpload,
  });

  Color get _chipColor {
    switch (verificationStatus) {
      case 'auto_verified':
        return AppColors.successGreen;
      case 'needs_review':
        return AppColors.warningAmber;
      case 'rejected':
        return AppColors.alertRed;
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  String _chipLabel(BuildContext context) {
    switch (verificationStatus) {
      case 'auto_verified':
        return context.tr('evidence_verified_chip');
      case 'needs_review':
        return context.tr('evidence_review_chip');
      case 'rejected':
        return context.tr('evidence_rejected_chip');
      default:
        return context.tr('evidence_upload_pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: verificationStatus == 'auto_verified'
            ? AppColors.successGreen.withOpacity(0.03)
            : Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Category label
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    categoryLabelMr,
                    style: const TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: Stack(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      context.tr('sample_document') == 'sample_document' 
                                          ? 'Sample Document' 
                                          : context.tr('sample_document'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                  Flexible(
                                    child: Image.asset(
                                      'assets/images/samples/$categoryKey.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => 
                                          const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text('Sample image not available'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined,
                            size: 14, color: AppColors.govtBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            context.tr('view_sample') == 'view_sample'
                                ? 'View Sample Document'
                                : context.tr('view_sample'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.govtBlue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Weight
            SizedBox(
              width: 36,
              child: Text(
                '${(weight * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Verdict chip
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _chipColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _chipColor.withOpacity(0.3)),
                ),
                child: Text(
                  _chipLabel(context),
                  style: TextStyle(
                    fontFamily: 'NotoSansDevanagari',
                    fontSize: 9,
                    color: _chipColor == const Color(0xFFCBD5E1)
                        ? const Color(0xFF6B7280)
                        : _chipColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Upload button
            SizedBox(
              width: 64,
              height: 30,
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.govtBlue,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: onUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.govtBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontSize: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: Text(context.tr('evidence_btn_upload')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
