import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A tappable action card in the look of the host's dashboard cards: rounded white card, a
/// coloured icon tile on the left, a title and one line of help, a chevron on the right.
/// [highlight] fills the tile with the accent colour (used for "Ask AI").
class LvActionCard extends StatelessWidget {
  const LvActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.isDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: dark ? c.cardBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlight
                  ? accent.withValues(alpha: 0.55)
                  : (dark ? const Color(0xFF2B5A46) : const Color(0xFFEEF2EF)),
              width: highlight ? 1.5 : 1,
            ),
            boxShadow: dark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: highlight
                        ? accent
                        : accent.withValues(alpha: dark ? 0.20 : 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 25,
                    color: highlight ? Colors.white : accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.textSecondary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
