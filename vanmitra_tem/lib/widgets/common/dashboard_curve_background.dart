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
      ..color = const Color(0xFF143526) // Deep forest green matching AppHeader top gradient
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
    // Starts curving down aggressively, then smoothly levels out at the middle.
    path.cubicTo(
      w * 0.2, startY + (drop * 0.3), // Steeper downward pull
      w * 0.35, midY,                 // Horizontal pull into center
      w * 0.5, midY,
    );

    // 3. Second S segment (Right half)
    // Leaves horizontally from the middle, then curves down aggressively toward the right edge.
    path.cubicTo(
      w * 0.65, midY,                 // Horizontal pull out of center
      w * 0.8, endY - (drop * 0.3),   // Steeper downward pull
      w, endY,
    );

    // 4. Trace back to top-right and close
    path.lineTo(w, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
