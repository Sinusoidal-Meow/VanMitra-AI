import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../livelihood_routes.dart';
import '../livelihood_strings.dart';
import '../models/ask.dart';
import 'lv_badges.dart';

/// One reply in the Ask box. Four looks, one for each kind of reply:
/// - an answer from his report: a normal card, ending "From: ...";
/// - a harmful question: RED, with the policy link and nothing else (red is used for this only);
/// - off topic, or not in the report: GREY, with the plain next step.
/// Every one carries an icon AND words, so colour is never the only signal.
class AnswerCard extends StatelessWidget {
  const AnswerCard(this.answer, {super.key});

  final Answer answer;

  @override
  Widget build(BuildContext context) {
    final s = LivelihoodStrings.of(context);
    final c = context.colors;
    final refused = answer.kind == AnswerKind.refusedHarmful;
    final grey = answer.kind == AnswerKind.offTopic ||
        answer.kind == AnswerKind.notInReport;

    final Color background = refused
        ? (c.isDark
            ? AppColors.alertRed.withValues(alpha: 0.18)
            : AppColors.errorLight)
        : grey
            ? c.sunkenBg
            : c.cardBg;
    final Color border = refused ? AppColors.alertRed : c.border;
    final IconData icon = refused
        ? Icons.block_rounded
        : grey
            ? Icons.info_outline_rounded
            : Icons.chat_bubble_outline_rounded;
    final Color iconColor = refused ? AppColors.alertRed : c.textSecondary;

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border, width: refused ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    answer.text ?? s.reason(answer.headline),
                    style: AppTypography.bodyLarge.copyWith(
                      color: c.textPrimary,
                      fontWeight: grey ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            for (final item in answer.items) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style:
                          AppTypography.body.copyWith(color: c.textSecondary),
                    ),
                    Expanded(
                      child: Text(
                        s.reason(item),
                        style:
                            AppTypography.body.copyWith(color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (refused)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(LivelihoodRoutes.policy),
                  child: Text(s.t('lv_policy_link')),
                ),
              ),
            if (answer.isAi) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 18, color: c.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.t('ask.ai_label'),
                      style: AppTypography.caption
                          .copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (answer.kind == AnswerKind.answer &&
                answer.fromParts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                s.t('ask.from', {
                  'parts': answer.fromParts
                      .map((p) => s.t('ask.part.$p'))
                      .join(', '),
                }),
                style: AppTypography.caption.copyWith(color: c.textSecondary),
              ),
            ],
            if (answer.isSampleData && answer.kind == AnswerKind.answer) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const SampleChip(),
                  Text(
                    s.t('ask.sample_note'),
                    style:
                        AppTypography.caption.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What he typed (or tapped), on the right.
class QuestionBubble extends StatelessWidget {
  const QuestionBubble(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: c.isDark ? AppColors.forestSage : AppColors.forestMist,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              color: c.isDark ? Colors.white : AppColors.forestDeep,
            ),
          ),
        ),
      ),
    );
  }
}
