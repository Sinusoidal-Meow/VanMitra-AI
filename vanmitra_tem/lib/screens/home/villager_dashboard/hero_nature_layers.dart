// Decorative nature layers of the villager hero, each a separate widget so the
// composition can be adjusted piece by piece: leaves (left and right), distant hills,
// a tree line, a small village, the sun and a few birds. All are low-contrast tones of
// the VanMitra greens over the dark hero green, never the focal point, and ignore taps.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tones used by the layers (from the dashboard design reference).
class HeroTones {
  static const base = Color(0xFF143526);
  static const farHill = Color(0xFF1B4332);
  static const midHill = Color(0xFF1E4D3A);
  static const nearHill = Color(0xFF245C43);
  static const tree = Color(0xFF2E705B);
  static const leafDark = Color(0xFF1E4D3A);
  static const leafLight = Color(0xFF2E705B);
  static const sun = Color(0xFFFFB259);
  static const hutWall = Color(0xFFCFE7D6);
  static const hutRoof = Color(0xFFD96B00);
  static const bird = Color(0xFFCFE7D6);
}

class _Layer extends StatelessWidget {
  const _Layer(this.painter);
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: RepaintBoundary(child: CustomPaint(painter: painter)));
}

// ── Layer A: leaves framing the hero at the screen edges ─────────────────────────────

class HeroLeaves extends StatelessWidget {
  const HeroLeaves({super.key, this.mirrored = false});

  /// false: a cluster for the left edge; true: mirrored for the right edge.
  final bool mirrored;

  @override
  Widget build(BuildContext context) => _Layer(_LeavesPainter(mirrored));
}

class _LeavesPainter extends CustomPainter {
  _LeavesPainter(this.mirrored);
  final bool mirrored;

  @override
  void paint(Canvas canvas, Size s) {
    if (mirrored) {
      canvas.translate(s.width, 0);
      canvas.scale(-1, 1);
    }
    // (x, y, length, angle, light?) relative to the box; leaves lean in from the edge.
    const leaves = [
      (0.10, 0.18, 0.42, 0.55, false),
      (0.05, 0.40, 0.50, 0.85, true),
      (0.12, 0.62, 0.46, 0.35, false),
      (0.02, 0.82, 0.40, 1.05, true),
      (0.20, 0.95, 0.34, 0.65, false),
    ];
    final stem = Paint()
      ..color = HeroTones.leafLight.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final (fx, fy, len, angle, light) in leaves) {
      final length = s.height * len;
      canvas.save();
      canvas.translate(s.width * fx, s.height * fy);
      canvas.rotate(angle);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * 0.5, -length * 0.22, length, 0)
        ..quadraticBezierTo(length * 0.5, length * 0.22, 0, 0)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..color = (light ? HeroTones.leafLight : HeroTones.leafDark)
              .withValues(alpha: 0.75),
      );
      canvas.drawLine(Offset.zero, Offset(length * 0.9, 0), stem);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeavesPainter old) => old.mirrored != mirrored;
}

// ── Layer B: distant rolling hills (horizontal bands) ────────────────────────────────

class HeroHills extends StatelessWidget {
  const HeroHills({super.key});

  @override
  Widget build(BuildContext context) => const _Layer(_HillsPainter());
}

class _HillsPainter extends CustomPainter {
  const _HillsPainter();

  Path _band(Size s, double topFrac, double amp, double phase, double waves) {
    final p = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width + 4; x += 4) {
      final y = s.height * topFrac -
          amp * math.sin((x / s.width) * math.pi * waves + phase);
      p.lineTo(x, y);
    }
    return p
      ..lineTo(s.width, s.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(_band(s, 0.30, s.height * 0.10, 0.6, 2.0),
        Paint()..color = HeroTones.farHill);
    canvas.drawPath(_band(s, 0.52, s.height * 0.08, 2.1, 2.6),
        Paint()..color = HeroTones.midHill);
    canvas.drawPath(_band(s, 0.74, s.height * 0.06, 1.2, 2.2),
        Paint()..color = HeroTones.nearHill);
  }

  @override
  bool shouldRepaint(_HillsPainter old) => false;
}

// ── Layer C: a distant tree line of small repeated silhouettes ──────────────────────

class HeroTreeLine extends StatelessWidget {
  const HeroTreeLine({super.key});

  @override
  Widget build(BuildContext context) => const _Layer(_TreeLinePainter());
}

class _TreeLinePainter extends CustomPainter {
  const _TreeLinePainter();

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()..color = HeroTones.tree.withValues(alpha: 0.85);
    // Varying heights; a gap in the middle-right leaves room for the village and sun.
    const trees = [
      (0.02, 0.85),
      (0.06, 1.0),
      (0.10, 0.75),
      (0.14, 0.92),
      (0.18, 0.7),
      (0.22, 0.86),
      (0.27, 0.66),
      (0.31, 0.8),
      (0.36, 0.6),
      (0.41, 0.72),
      (0.46, 0.58),
      (0.84, 0.7),
      (0.88, 0.92),
      (0.92, 0.78),
      (0.96, 1.0),
      (0.995, 0.8),
    ];
    for (final (fx, fh) in trees) {
      final x = s.width * fx;
      final h = s.height * fh;
      final w = h * 0.42;
      canvas.drawPath(
        Path()
          ..moveTo(x, s.height - h)
          ..lineTo(x + w / 2, s.height)
          ..lineTo(x - w / 2, s.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TreeLinePainter old) => false;
}

// ── Layer D: a tiny village hut ───────────────────────────────────────────────────

class HeroVillage extends StatelessWidget {
  const HeroVillage({super.key});

  @override
  Widget build(BuildContext context) => const _Layer(_VillagePainter());
}

class _VillagePainter extends CustomPainter {
  const _VillagePainter();

  @override
  void paint(Canvas canvas, Size s) {
    final wallTop = s.height * 0.45;
    canvas.drawRect(
      Rect.fromLTWH(s.width * 0.15, wallTop, s.width * 0.7, s.height - wallTop),
      Paint()..color = HeroTones.hutWall.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, wallTop + 1)
        ..lineTo(s.width / 2, 0)
        ..lineTo(s.width, wallTop + 1)
        ..close(),
      Paint()..color = HeroTones.hutRoof.withValues(alpha: 0.9),
    );
    canvas.drawRect(
      Rect.fromLTWH(
          s.width * 0.42, s.height * 0.68, s.width * 0.16, s.height * 0.32),
      Paint()..color = HeroTones.base.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_VillagePainter old) => false;
}

// ── Layer E: an understated sun / light circle ────────────────────────────────────

class HeroSun extends StatelessWidget {
  const HeroSun({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HeroTones.sun.withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                  color: HeroTones.sun.withValues(alpha: 0.25), blurRadius: 14)
            ],
          ),
        ),
      );
}

// ── Layer F: a few small birds ────────────────────────────────────────────────────

class HeroBirds extends StatelessWidget {
  const HeroBirds({super.key});

  @override
  Widget build(BuildContext context) => const _Layer(_BirdsPainter());
}

class _BirdsPainter extends CustomPainter {
  const _BirdsPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = HeroTones.bird.withValues(alpha: 0.45)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (fx, fy, size) in const [
      (0.15, 0.55, 5.0),
      (0.45, 0.25, 4.0),
      (0.75, 0.6, 3.5)
    ]) {
      final o = Offset(s.width * fx, s.height * fy);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - size, o.dy)
          ..quadraticBezierTo(o.dx - size / 2, o.dy - size * 0.7, o.dx, o.dy)
          ..quadraticBezierTo(
              o.dx + size / 2, o.dy - size * 0.7, o.dx + size, o.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BirdsPainter old) => false;
}
