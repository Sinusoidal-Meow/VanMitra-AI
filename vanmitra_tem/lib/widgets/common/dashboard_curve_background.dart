import 'package:flutter/material.dart';

/// Deep forest green of the dashboard hero (matches the app header).
const Color dashboardHeroGreen = Color(0xFF143526);

/// The green area above the S-curve: high on the left, low on the right, with a long
/// flat middle. [startY] is where the curve leaves the left edge; [dropFactor] × width
/// is how much lower it reaches the right edge.
///
/// The defaults are the admin dashboard's curve. Other dashboards pass their own values.
Path dashboardCurvePath(Size size,
    {double startY = 110.0, double dropFactor = 0.45}) {
  final w = size.width;
  final drop = w * dropFactor;
  final endY = startY + drop;
  final midY = startY + drop / 2;

  return Path()
    ..moveTo(0, 0)
    ..lineTo(0, startY)
    // Left half: leaves the edge, drops early, then runs long and flat.
    ..cubicTo(w * 0.08, startY + drop * 0.05, w * 0.15, midY, w * 0.60, midY)
    // Right half: holds the flat middle far out, then drops near the right edge.
    ..cubicTo(w * 0.92, midY, w * 0.92, endY - drop * 0.05, w, endY)
    ..lineTo(w, 0)
    ..close();
}

class DashboardCurveBackground extends StatelessWidget {
  const DashboardCurveBackground({
    super.key,
    this.startY = 110.0,
    this.dropFactor = 0.45,
    this.color = dashboardHeroGreen,
  });

  final double startY;
  final double dropFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Positioned.fill lets the painter use the full width and draw responsively.
    return Positioned.fill(
      child: CustomPaint(
        painter: _SCurvePainter(
            startY: startY, dropFactor: dropFactor, color: color),
      ),
    );
  }
}

/// Clips decorative layers to the same green area, so they never spill past the curve.
class DashboardCurveClipper extends CustomClipper<Path> {
  const DashboardCurveClipper({this.startY = 110.0, this.dropFactor = 0.45});

  final double startY;
  final double dropFactor;

  @override
  Path getClip(Size size) =>
      dashboardCurvePath(size, startY: startY, dropFactor: dropFactor);

  @override
  bool shouldReclip(DashboardCurveClipper old) =>
      old.startY != startY || old.dropFactor != dropFactor;
}

class _SCurvePainter extends CustomPainter {
  _SCurvePainter(
      {required this.startY, required this.dropFactor, required this.color});

  final double startY;
  final double dropFactor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      dashboardCurvePath(size, startY: startY, dropFactor: dropFactor),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_SCurvePainter old) =>
      old.startY != startY ||
      old.dropFactor != dropFactor ||
      old.color != color;
}
