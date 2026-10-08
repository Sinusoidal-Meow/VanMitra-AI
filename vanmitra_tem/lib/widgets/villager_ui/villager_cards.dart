// Small building blocks shared by the villager screens: the soft white card, section
// titles, status pills, the documentation checklist and plain-language error messages.

import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

/// White rounded card with a very soft shadow (dark-mode aware).
class VmCard extends StatelessWidget {
  const VmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: borderColor ??
                (c.isDark ? c.border : const Color(0xFFE8EFEA))),
        boxShadow: c.isDark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, 6)),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Bold section heading, optionally with something on the right.
class VmSectionTitle extends StatelessWidget {
  const VmSectionTitle(this.text, {super.key, this.trailing, this.subtitle});

  final String text;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded label with a tinted background, e.g. a claim state or "Verified".
class StatusPill extends StatelessWidget {
  const StatusPill(
      {super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// A small chip naming the legal rule, e.g. [Rule 13(2)].
class RuleTag extends StatelessWidget {
  const RuleTag(this.rule, {super.key});
  final String rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(rule,
          style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 10.5,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// One line of a documentation checklist.
class ChecklistLine {
  const ChecklistLine(
      {required this.ok, required this.text, required this.rule});
  final bool ok;
  final String text;
  final String rule;
}

/// "N of M recorded" with each item ticked or open, and its rule. Advisory only:
/// never a score, never a prediction.
class ChecklistCard extends StatelessWidget {
  const ChecklistCard({
    super.key,
    required this.title,
    required this.lines,
    this.footnote,
  });

  final String title;
  final List<ChecklistLine> lines;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = lines.where((l) => l.ok).length;
    final progress = lines.isEmpty ? 0.0 : done / lines.length;
    return VmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded,
                  color: Color(0xFF2E705B), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              Text('$done of ${lines.length}',
                  style: const TextStyle(
                      color: Color(0xFF2E705B),
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: c.isDark
                  ? const Color(0xFF23382B)
                  : const Color(0xFFE6F0EA),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2E705B)),
            ),
          ),
          const SizedBox(height: 10),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    l.ok
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: l.ok
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFFF8A00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.text,
                        style: TextStyle(
                            color: l.ok ? c.textSecondary : c.textPrimary,
                            fontSize: 13,
                            height: 1.3)),
                  ),
                  const SizedBox(width: 6),
                  RuleTag(l.rule),
                ],
              ),
            ),
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(footnote!,
                style: TextStyle(color: c.textTertiary, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

// ── Claim states in plain words ─────────────────────────────────────────────────

String claimStateLabel(String state) => switch (state) {
      'draft' => 'Draft · मसुदा',
      'gs_review' => 'With Gram Sabha',
      'sdo_review' => 'With SDO',
      'district_review' => 'At district',
      'title_issued' => 'Title issued · सनद',
      'rejected' => 'Rejected · नाकारले',
      'expired' => 'Expired',
      _ => state,
    };

Color claimStateColor(String state) => switch (state) {
      'draft' => const Color(0xFFE07A00),
      'gs_review' => const Color(0xFF1E6FB8),
      'sdo_review' => const Color(0xFF6B4BB8),
      'district_review' => const Color(0xFF3949AB),
      'title_issued' => const Color(0xFF2E7D32),
      'rejected' => const Color(0xFFC62828),
      'expired' => const Color(0xFF757575),
      _ => const Color(0xFF607D8B),
    };

String formTitle(String claimType) => switch (claimType) {
      'cfr' => 'Form C · Community forest resource',
      'cr' => 'Form B · Community rights',
      'ifr' => 'Form A · Individual claim',
      _ => claimType,
    };

// ── Errors in plain words ───────────────────────────────────────────────────────

const Map<String, String> _errorText = {
  'NOT_ALLOWED_TO_OPEN_FORM': 'Your role cannot open this kind of claim.',
  'GRAM_SABHA_MISSING': 'This village has no Gram Sabha set up on the server yet.',
  'CASE_NOT_EDITABLE': 'This claim is no longer a draft, so it cannot be changed.',
  'ONLY_CLAIMANT_CAN_EDIT': 'Only the person who opened this claim can change it.',
  'CANNOT_MAP_NOW': 'The boundary can be changed only while the claim is your draft.',
  'BOUNDARY_FROZEN': 'The Gram Sabha has approved this boundary; it can no longer change.',
  'INVALID_GEOMETRY': 'The boundary shape is not valid (lines cross or too few points).',
  'NO_BOUNDARY': 'Save the boundary first.',
  'CANNOT_ADD_EVIDENCE_NOW': 'Evidence can be added only while the claim is your draft.',
  'MEDIA_NOT_YOURS': 'That file was uploaded by someone else.',
  'UNSUPPORTED_MEDIA_TYPE': 'This file type is not accepted (use a photo or PDF).',
  'FILE_TOO_LARGE': 'The file is too large (20 MB at most).',
  'NOT_YOUR_LEVEL': 'This step belongs to another level (Gram Sabha or SDO).',
  'TITLE_NOT_AVAILABLE': 'The title draft appears once the claim reaches the district.',
  'NOT_YET_FILED': 'A receipt is issued once the claim is submitted.',
  'NETWORK_OR_SERVER_ERROR': 'Could not reach the server. Check the connection.',
};

/// A short, plain message for any error from the server or the network.
String apiErrorText(Object e) {
  if (e is ApiException) {
    final text = _errorText[e.error] ??
        e.messageKey.replaceAll(RegExp(r'[._]'), ' ').trim();
    return e.rule != null ? '$text [${e.rule}]' : text;
  }
  return 'Could not reach the server. Check the connection.';
}

void showApiError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(apiErrorText(e)),
    backgroundColor: const Color(0xFFB3261E),
  ));
}

void showDone(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text),
    backgroundColor: const Color(0xFF2E7D32),
  ));
}
