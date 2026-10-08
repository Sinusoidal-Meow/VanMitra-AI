// Content cards of the villager dashboard, from the design reference: Next Meeting,
// the three statistics, the Claims header with its "Quick Actions" label, and the claim
// action cards. White cards with soft shadows in light mode; the theme's dark surfaces
// in dark mode (context.colors), so the dashboard switches theme as one.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/illustrations/vanmitra_illustrations.dart';

/// Colours from the dashboard reference.
class DashTones {
  static const title = Color(0xFF143526);
  static const subtitle = Color(0xFF64748B);
  static const orange = Color(0xFFFF8A00);
  static const neutralIconBg = Color(0xFFF1F5F9);
  static const greenIconBg = Color(0xFFE8F5EE);
  static const blueIconBg = Color(0xFFE0F2FE);
  static const orangeIconBg = Color(0xFFFFF3E3);
  static const amberIconBg = Color(0xFFFFF8E1);
  static const green = Color(0xFF2E705B);
  static const blue = Color(0xFF2F5FB3);
  static const amber = Color(0xFFF0B323);
}

class _Look {
  _Look(BuildContext context) : c = context.colors;
  final AppThemeColors c;

  bool get dark => c.isDark;
  Color get surface => dark ? c.cardBg : Colors.white;
  Color get title => dark ? c.textPrimary : DashTones.title;
  Color get subtitle => dark ? c.textSecondary : DashTones.subtitle;
  Color iconBg(Color light, Color accent) =>
      dark ? accent.withValues(alpha: 0.20) : light;

  BoxDecoration card(double radius) => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: dark ? const Color(0xFF2B5A46) : const Color(0xFFEEF2EF)),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 14,
                    offset: Offset(0, 4))
              ],
      );
}

class _ChevronCircle extends StatelessWidget {
  const _ChevronCircle();

  @override
  Widget build(BuildContext context) {
    final look = _Look(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: look.iconBg(DashTones.neutralIconBg, look.subtitle),
      ),
      child: Icon(Icons.chevron_right_rounded, size: 20, color: look.subtitle),
    );
  }
}

/// A tappable card: InkWell ripple inside the rounded card.
class _TapCard extends StatelessWidget {
  const _TapCard(
      {required this.radius,
      required this.child,
      this.onTap,
      this.height,
      this.padding});

  final double radius;
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          height: height,
          padding: padding,
          decoration: _Look(context).card(radius),
          child: child,
        ),
      ),
    );
  }
}

// ── 08 · Next Meeting ───────────────────────────────────────────────────────────────

class NextMeetingCard extends StatelessWidget {
  const NextMeetingCard(
      {super.key, required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final look = _Look(context);
    return _TapCard(
      radius: 20,
      height: 88,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: look.iconBg(DashTones.neutralIconBg, look.subtitle),
            ),
            child:
                Icon(Icons.event_busy_rounded, color: look.subtitle, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: look.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: look.subtitle, fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            width: 74,
            height: 58,
            child: CustomPaint(
                painter: CardArtPainter(CardArt.calendar, dark: look.dark)),
          ),
          const SizedBox(width: 6),
          const _ChevronCircle(),
        ],
      ),
    );
  }
}

// ── 09 · Statistics row ─────────────────────────────────────────────────────────────

class StatCardData {
  const StatCardData({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.iconBg,
    required this.art,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final Color iconBg;
  final CardArt art;
  final VoidCallback? onTap;
}

/// Three equal, compact statistic cards.
class DashboardStatsRow extends StatelessWidget {
  const DashboardStatsRow({super.key, required this.cards});

  final List<StatCardData> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: StatCard(data: cards[i])),
        ],
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.data});

  final StatCardData data;

  @override
  Widget build(BuildContext context) {
    final look = _Look(context);
    return _TapCard(
      radius: 18,
      height: 100,
      onTap: data.onTap,
      child: Stack(
        children: [
          // Faint illustration, top right.
          Positioned(
            right: 6,
            top: 8,
            width: 46,
            height: 40,
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(
                  painter: CardArtPainter(data.art, dark: look.dark)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: look.iconBg(data.iconBg, data.accent),
                  ),
                  child: Icon(data.icon, color: data.accent, size: 18),
                ),
                const Spacer(),
                Text(
                  data.value,
                  style: TextStyle(
                      color: look.title,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: look.subtitle, fontSize: 11.5),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 15, color: look.subtitle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 10 · Claims section header ─────────────────────────────────────────────────────

class ClaimsSectionHeader extends StatelessWidget {
  const ClaimsSectionHeader(
      {super.key, required this.title, required this.label, this.onLabelTap});

  final String title;
  final String label;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final look = _Look(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(title,
              style: TextStyle(
                  color: look.title,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        GestureDetector(
          onTap: onLabelTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label,
                  style: TextStyle(
                      color: look.subtitle,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  color: DashTones.orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 11–13 · Claim action cards ─────────────────────────────────────────────────────

class ClaimActionCard extends StatelessWidget {
  const ClaimActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.iconBg,
    required this.art,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color iconBg;
  final CardArt art;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final look = _Look(context);
    return _TapCard(
      radius: 20,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: look.iconBg(iconBg, accent),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line: a long title shrinks slightly instead of wrapping.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        maxLines: 1,
                        style: TextStyle(
                            color: look.title,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: look.subtitle, fontSize: 12.5, height: 1.3)),
                ],
              ),
            ),
            SizedBox(
              width: 58,
              height: 46,
              child: Opacity(
                opacity: 0.35,
                child:
                    CustomPaint(painter: CardArtPainter(art, dark: look.dark)),
              ),
            ),
            const SizedBox(width: 4),
            const _ChevronCircle(),
          ],
        ),
      ),
    );
  }
}
