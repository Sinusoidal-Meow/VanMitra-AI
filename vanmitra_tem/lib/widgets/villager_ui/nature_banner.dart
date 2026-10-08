// A light landscape strip for the top of villager screens (My Claims, Gram Sabha
// Records, a claim page): pale sky, a low sun, three bands of hills, tree clusters at
// both edges, a small house and a few birds, ending in a soft wave into the page.
// Painted, not an image, so it scales to any width and costs almost nothing.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class NatureBanner extends StatelessWidget {
  const NatureBanner({super.key, this.height = 96, this.child});

  final double height;

  /// Optional content laid over the banner (e.g. a summary card), bottom-aligned.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _LandscapePainter(dark: dark)),
              ),
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter({required this.dark});
  final bool dark;

  static const _sun = Color(0xFFFFB259);
  static const _farHill = Color(0xFFCFE7D6);
  static const _midHill = Color(0xFF9FCFAE);
  static const _nearHill = Color(0xFF5FA57A);
  static const _tree = Color(0xFF2E705B);
  static const _treeDark = Color(0xFF1E4D3A);
  static const _wall = Color(0xFFFFF4E0);
  static const _roof = Color(0xFFD96B00);

  Path _hill(Size s, double baseFrac, double amp, double phase, double waves) {
    final p = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width + 4; x += 4) {
      final y = s.height * baseFrac -
          amp * math.sin((x / s.width) * math.pi * waves + phase);
      p.lineTo(x, y);
    }
    return p
      ..lineTo(s.width, s.height)
      ..close();
  }

  void _drawTree(Canvas c, double x, double baseY, double h, Color color) {
    final w = h * 0.55;
    c.drawPath(
      Path()
        ..moveTo(x, baseY - h)
        ..quadraticBezierTo(x + w * 0.62, baseY - h * 0.45, x + w / 2, baseY)
        ..lineTo(x - w / 2, baseY)
        ..quadraticBezierTo(x - w * 0.62, baseY - h * 0.45, x, baseY - h)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final page = dark ? const Color(0xFF0F1A14) : Colors.white;

    // Sky: pale green fading towards the page colour.
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF16291F), const Color(0xFF0F1A14)]
              : [const Color(0xFFE6F3EA), const Color(0xFFF5FBF7)],
        ).createShader(Offset.zero & s),
    );

    // Sun, low on the right, half behind the hills.
    final sunC = Offset(w * 0.80, h * 0.50);
    canvas.drawCircle(sunC, h * 0.28,
        Paint()..color = _sun.withValues(alpha: dark ? 0.15 : 0.22));
    canvas.drawCircle(sunC, h * 0.17, Paint()..color = _sun);

    // Birds.
    final bird = Paint()
      ..color = const Color(0xFF2E705B).withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final (fx, fy, r) in const [
      (0.52, 0.16, 4.5),
      (0.58, 0.10, 3.5),
      (0.63, 0.20, 3.0),
    ]) {
      final o = Offset(w * fx, h * fy);
      canvas.drawPath(
        Path()
          ..moveTo(o.dx - r, o.dy)
          ..quadraticBezierTo(o.dx - r / 2, o.dy - r * 0.7, o.dx, o.dy)
          ..quadraticBezierTo(o.dx + r / 2, o.dy - r * 0.7, o.dx + r, o.dy),
        bird,
      );
    }

    // Hills, far to near.
    final a = dark ? 0.45 : 1.0;
    canvas.drawPath(_hill(s, 0.58, h * 0.12, 0.4, 2.2),
        Paint()..color = _farHill.withValues(alpha: a));
    canvas.drawPath(_hill(s, 0.70, h * 0.10, 2.0, 2.8),
        Paint()..color = _midHill.withValues(alpha: a));

    // A small house on the middle hill, right of centre.
    final hx = w * 0.70;
    final hy = h * 0.70;
    final hw = h * 0.20;
    canvas.drawRect(Rect.fromLTWH(hx - hw / 2, hy - hw * 0.55, hw, hw * 0.55),
        Paint()..color = _wall);
    canvas.drawPath(
      Path()
        ..moveTo(hx - hw * 0.65, hy - hw * 0.52)
        ..lineTo(hx, hy - hw * 1.05)
        ..lineTo(hx + hw * 0.65, hy - hw * 0.52)
        ..close(),
      Paint()..color = _roof,
    );
    canvas.drawRect(
        Rect.fromLTWH(hx - hw * 0.1, hy - hw * 0.3, hw * 0.2, hw * 0.3),
        Paint()..color = _roof.withValues(alpha: 0.8));

    canvas.drawPath(_hill(s, 0.84, h * 0.08, 1.1, 2.0),
        Paint()..color = _nearHill.withValues(alpha: a));

    // Tree clusters framing both edges, plus a few on the far ridge.
    final base = h * 0.86;
    for (final (fx, fh, d) in const [
      (0.03, 0.62, true),
      (0.08, 0.48, false),
      (0.13, 0.36, true),
      (0.88, 0.40, false),
      (0.93, 0.58, true),
      (0.98, 0.46, false),
    ]) {
      _drawTree(canvas, w * fx, base, h * fh, d ? _treeDark : _tree);
    }
    for (final fx in const [0.30, 0.34, 0.40, 0.46]) {
      _drawTree(canvas, w * fx, h * 0.62, h * 0.16, _tree.withValues(alpha: 0.7));
    }

    // Soft wave into the page below.
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.90)
        ..cubicTo(w * 0.30, h * 0.80, w * 0.62, h * 1.0, w, h * 0.88)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = page,
    );
  }

  @override
  bool shouldRepaint(_LandscapePainter old) => old.dark != dark;
}
