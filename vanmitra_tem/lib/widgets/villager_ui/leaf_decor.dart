// Faint leaf sprigs used as quiet decoration on villager screens: in the corners of a
// page and on either side of an empty-state icon. Never interactive.

import 'package:flutter/material.dart';

/// A sprig of leaves along a curved stem. [mirrored] flips it to lean the other way.
class LeafSprig extends StatelessWidget {
  const LeafSprig({
    super.key,
    this.width = 40,
    this.height = 60,
    this.mirrored = false,
    this.opacity = 0.35,
  });

  final double width;
  final double height;
  final bool mirrored;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(painter: _SprigPainter(mirrored, opacity)),
        ),
      );
}

/// Large, very faint leaves for the bottom-left (or right) corner of a page.
class LeafCorner extends StatelessWidget {
  const LeafCorner({super.key, this.size = 150, this.mirrored = false});

  final double size;
  final bool mirrored;

  @override
  Widget build(BuildContext context) => LeafSprig(
        width: size,
        height: size * 1.2,
        mirrored: mirrored,
        opacity: 0.12,
      );
}

class _SprigPainter extends CustomPainter {
  _SprigPainter(this.mirrored, this.opacity);
  final bool mirrored;
  final double opacity;

  @override
  void paint(Canvas canvas, Size s) {
    if (mirrored) {
      canvas.translate(s.width, 0);
      canvas.scale(-1, 1);
    }
    final leaf = Paint()..color = const Color(0xFF2E705B).withValues(alpha: opacity);
    final light = Paint()..color = const Color(0xFF5FA57A).withValues(alpha: opacity);
    final stem = Paint()
      ..color = const Color(0xFF2E705B).withValues(alpha: opacity)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Stem: from the bottom-left, curving up and to the right.
    final p0 = Offset(s.width * 0.15, s.height);
    final p1 = Offset(s.width * 0.25, s.height * 0.45);
    final p2 = Offset(s.width * 0.85, s.height * 0.05);
    canvas.drawPath(
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
        stem);

    Offset at(double t) {
      final u = 1 - t;
      return Offset(
        u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
        u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
      );
    }

    // Leaves alternate sides of the stem, getting smaller towards the tip.
    const leaves = [
      (0.18, -0.9, 0.42),
      (0.32, 0.5, 0.40),
      (0.48, -1.1, 0.34),
      (0.62, 0.2, 0.30),
      (0.78, -1.3, 0.24),
      (0.92, -0.4, 0.18),
    ];
    var i = 0;
    for (final (t, angle, len) in leaves) {
      final o = at(t);
      final l = s.height * len;
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(angle);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(l * 0.5, -l * 0.26, l, 0)
          ..quadraticBezierTo(l * 0.5, l * 0.26, 0, 0)
          ..close(),
        i.isEven ? leaf : light,
      );
      canvas.restore();
      i++;
    }
  }

  @override
  bool shouldRepaint(_SprigPainter old) =>
      old.mirrored != mirrored || old.opacity != opacity;
}
