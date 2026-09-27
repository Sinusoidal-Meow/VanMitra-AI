import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../models/cfr_claim_stage_data.dart';
import '../models/claim.dart';
import '../models/user_role.dart';

/// 8 Legal Stages of the CFR Workflow Timeline
class CfrTimelineStage {
  final int stageNumber;
  final String titleEn;
  final String titleMr;
  final String descriptionEn;
  final String descriptionMr;

  const CfrTimelineStage({
    required this.stageNumber,
    required this.titleEn,
    required this.titleMr,
    required this.descriptionEn,
    required this.descriptionMr,
  });
}

const List<CfrTimelineStage> kCfrTimelineStages = [
  CfrTimelineStage(
    stageNumber: 1,
    titleEn: '1. Village / Claim Created',
    titleMr: '१. गाव / दावा दाखल',
    descriptionEn: 'FRC / Villager creates claim & assigns unique ID',
    descriptionMr: 'दावा नोंदणी व आयडी निर्मिती',
  ),
  CfrTimelineStage(
    stageNumber: 2,
    titleEn: '2. FRC Investigation',
    titleMr: '२. FRC चौकशी व अहवाल',
    descriptionEn: 'FRC verifies boundary, elders, and evidence',
    descriptionMr: 'प्रथागत सीमा व पुरावे पडताळणी',
  ),
  CfrTimelineStage(
    stageNumber: 3,
    titleEn: '3. Gram Sabha Resolution',
    titleMr: '३. ग्रामसभा ठराव',
    descriptionEn: 'Gram Sabha meeting quorum & resolution approval',
    descriptionMr: 'ग्रामसभा गणपूर्ती व मंजुरी ठराव',
  ),
  CfrTimelineStage(
    stageNumber: 4,
    titleEn: '4. Joint Field Verification',
    titleMr: '४. संयुक्त क्षेत्र पडताळणी',
    descriptionEn: 'Forest and Revenue Field Officers submit proceedings',
    descriptionMr: 'वन व महसूल अधिकारी पडताळणी',
  ),
  CfrTimelineStage(
    stageNumber: 5,
    titleEn: '5. SDLC Review',
    titleMr: '५. उपविभागीय स्तर समिती (SDLC)',
    descriptionEn: 'SDLC map consolidation & draft record preparation',
    descriptionMr: 'नकाशा एकत्रीकरण व मसुदा नोंद',
  ),
  CfrTimelineStage(
    stageNumber: 6,
    titleEn: '6. DLC Final Order',
    titleMr: '६. जिल्हा स्तर समिती (DLC)',
    descriptionEn: 'DLC final decision (Approve/Remand/Modify/Reject)',
    descriptionMr: 'DLC अंतिम निर्णय व आदेश',
  ),
  CfrTimelineStage(
    stageNumber: 7,
    titleEn: '7. Annexure IV Title Signatures',
    titleMr: '७. परिशिष्ट IV स्वाक्षरी',
    descriptionEn: 'Signatures by DFO, Tribal Welfare Officer & Collector',
    descriptionMr: 'DFO, प्रकल्प अधिकारी व जिल्हाधिकारी स्वाक्षरी',
  ),
  CfrTimelineStage(
    stageNumber: 8,
    titleEn: '8. Record Incorporation',
    titleMr: '८. अभिलेख नोंदणी पूर्ण',
    descriptionEn: 'Final title incorporated into Forest & Revenue land records',
    descriptionMr: 'महसूल व वन अभिलेखात अधिकृत नोंद',
  ),
];

/// Visual Timeline Widget generated dynamically from claim audit trail
class CfrStatusTimelineWidget extends StatelessWidget {
  final Claim claim;

  const CfrStatusTimelineWidget({super.key, required this.claim});

  int get _currentStageNumber {
    switch (claim.status) {
      case ClaimStatus.draft:
      case ClaimStatus.submittedToFrc:
        return 1;
      case ClaimStatus.frcReview:
        return 2;
      case ClaimStatus.gramSabhaReview:
      case ClaimStatus.gramSabhaReturned:
      case ClaimStatus.gramSabhaApproved:
        return 3;
      case ClaimStatus.fieldVerificationPending:
      case ClaimStatus.fieldVerificationInProgress:
      case ClaimStatus.fieldVerificationCompleted:
        return 4;
      case ClaimStatus.sdlcReview:
      case ClaimStatus.sdlcReturned:
      case ClaimStatus.sdlcApproved:
      case ClaimStatus.forwardedToDlc:
        return 5;
      case ClaimStatus.dlcReview:
      case ClaimStatus.dlcRemanded:
      case ClaimStatus.dlcModified:
      case ClaimStatus.dlcRejected:
      case ClaimStatus.dlcApproved:
        return 6;
      case ClaimStatus.annexureIvPendingDfo:
      case ClaimStatus.annexureIvPendingTribalWelfare:
      case ClaimStatus.annexureIvPendingCollector:
      case ClaimStatus.annexureIvCompleted:
        return 7;
      case ClaimStatus.recordIncorporationPending:
      case ClaimStatus.recordIncorporated:
      case ClaimStatus.completed:
        return 8;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = _currentStageNumber;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline_rounded, color: AppColors.saffron),
                const SizedBox(width: 8),
                const Text(
                  'CFR Workflow Stage Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestCanopy,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.saffron.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Stage $currentStage of 8',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.saffron,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kCfrTimelineStages.length,
              itemBuilder: (context, index) {
                final stage = kCfrTimelineStages[index];
                final isCompleted = stage.stageNumber < currentStage ||
                    (stage.stageNumber == 8 &&
                        claim.status == ClaimStatus.completed);
                final isCurrent = stage.stageNumber == currentStage &&
                    claim.status != ClaimStatus.completed;
                final isRejected = isCurrent && claim.status.isRejected;

                WorkflowEvent? stageEvent;
                try {
                  stageEvent = claim.auditTrail.lastWhere((e) =>
                      e.newState.toLowerCase().contains(stage.titleEn
                          .split(' ')[1]
                          .toLowerCase()));
                } catch (_) {}

                return _buildTimelineTile(
                  context,
                  stage: stage,
                  isCompleted: isCompleted,
                  isCurrent: isCurrent,
                  isRejected: isRejected,
                  isLast: index == kCfrTimelineStages.length - 1,
                  event: stageEvent,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineTile(
    BuildContext context, {
    required CfrTimelineStage stage,
    required bool isCompleted,
    required bool isCurrent,
    required bool isRejected,
    required bool isLast,
    WorkflowEvent? event,
  }) {
    Color circleColor;
    IconData iconData;

    if (isCompleted) {
      circleColor = AppColors.successGreen;
      iconData = Icons.check_circle_rounded;
    } else if (isCurrent) {
      circleColor = isRejected ? AppColors.alertRed : AppColors.saffron;
      iconData =
          isRejected ? Icons.cancel_rounded : Icons.pending_actions_rounded;
    } else {
      circleColor = Colors.grey.shade400;
      iconData = Icons.radio_button_unchecked_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor.withOpacity(0.15),
                ),
                child: Icon(iconData, size: 18, color: circleColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? AppColors.successGreen.withOpacity(0.5)
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.titleEn,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: isCurrent
                          ? (isRejected
                              ? AppColors.alertRed
                              : AppColors.saffron)
                          : (isCompleted
                              ? AppColors.forestCanopy
                              : Colors.grey.shade700),
                    ),
                  ),
                  Text(
                    stage.titleMr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stage.descriptionEn,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (event != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.comment,
                            style: const TextStyle(
                                fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Updated by ${event.actorRole.displayNameEn} • ${DateFormat('dd MMM yyyy, hh:mm a').format(event.timestamp)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
