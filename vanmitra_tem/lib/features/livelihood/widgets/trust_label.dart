import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_strings.dart';
import '../models/report.dart';

/// Source, date and check status. Nothing in the report appears without one (rule L1), and
/// it is always visible, not hidden behind a tap.
class TrustLabelView extends StatelessWidget {
  const TrustLabelView(this.trust, {super.key});

  final TrustLabel trust;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          trust.isConfirmed
              ? Icons.verified_rounded
              : Icons.fact_check_outlined,
          size: 14,
          color: trust.isConfirmed ? AppColors.successGreen : c.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            s.trustLine(trust),
            style: AppTypography.caption.copyWith(color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
