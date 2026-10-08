import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class DashboardCurveBackground extends StatelessWidget {
  const DashboardCurveBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // We use Positioned.fill to allow the CustomPainter to access the full available screen dimensions
    // and draw the responsive curve relative to the screen width.
    return Positioned.fill(
      child: CustomPaint(
        painter: _SCurvePainter(),
      ),
    );
  }
}

class _SCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // We use the VanMitra-AI dark green for the upper background
    // to match the app header.
    final paint = Paint()
      ..color = const Color(
          0xFF143526) // Deep forest green matching AppHeader top gradient
      ..style = PaintingStyle.fill;

    final path = Path();

    // The curve must start HIGH on the left and end LOW on the right.
    // We position the left start around the lower portion of the GreetingHero card.
    final double startY = 110.0;

    // INCREASED AMPLITUDE:
    // Vertical amplitude of the S-curve scales responsively with screen width.
    // Increased by ~1.8x to make the S-shape deeply pronounced and clearly visible
    // on both sides of the Total Claims card.
    final double drop = size.width * 0.45;
    final double endY = startY + drop;

    final double midY = startY + (drop / 2);
    final double w = size.width;

    // 1. Start at top-left (0,0) and go down to the start of the curve
    path.lineTo(0, startY);

    // 2. First S segment (Left half)
    // Stretches horizontally before dropping, then creates a VERY LONG flat middle section.
    path.cubicTo(
      w * 0.08,
      startY + (drop * 0.05), // Drop happens much earlier (closer to left edge)
      w * 0.15, midY, // Arrives at midY very early
      w * 0.60, midY, // Meet exactly in the center perfectly flat
    );

    // 3. Second S segment (Right half)
    // Maintains the long flat middle section out to 85% width before dropping.
    path.cubicTo(
      w * 0.92, midY, // Hold the flat center out very far
      w * 0.92, endY - (drop * 0.05), // Drop steeply toward the right edge
      w, endY, // End horizontally flat
    );

    // 4. Trace back to top-right and close
    path.lineTo(w, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
