// Small vector illustrations for the villager dashboard cards (drawn in code: crisp at any size,
// no image assets, and toned down automatically in dark mode). Colours follow the
// VanMitra-AI Theme & UI Style Guide: forest greens, warm orange, soft neutrals.

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared palette for the illustrations, light or dark.
class _Art {
  const _Art(this.dark);
  final bool dark;

  Color get sky => dark ? const Color(0xFF173425) : const Color(0xFFE7F1E6);
  Color get skyLow => dark ? const Color(0xFF10261B) : const Color(0xFFF6F2E4);
  Color get farHill => dark ? const Color(0xFF1F4A35) : const Color(0xFFC5DDC2);
  Color get midHill => dark ? const Color(0xFF245A40) : const Color(0xFF9CC79A);
  Color get nearHill =>
      dark ? const Color(0xFF2D765C) : const Color(0xFF6FA86E);
  Color get treeDark =>
      dark ? const Color(0xFF1A4331) : const Color(0xFF2D6A4F);
  Color get treeMid => dark ? const Color(0xFF2D765C) : const Color(0xFF52896A);
  Color get treeLight =>
      dark ? const Color(0xFF3E8A6B) : const Color(0xFF7FB37E);
  Color get trunk => dark ? const Color(0xFF4A3B2A) : const Color(0xFF8A6A48);
  Color get sun => dark ? const Color(0xFFD96B00) : const Color(0xFFFFB25C);
  Color get hutWall => dark ? const Color(0xFF6B5638) : const Color(0xFFE2C38F);
  Color get hutRoof => dark ? const Color(0xFF8A4A1C) : const Color(0xFFD96B00);
  Color get paper => dark ? const Color(0xFF2B5A46) : Colors.white;
  Color get line => dark ? const Color(0xFFAAB8B2) : const Color(0xFFB9C7BF);
  Color get orange => const Color(0xFFFF8D20);
  Color get red => const Color(0xFFD7262E);
  Color get green => dark ? const Color(0xFF5FAE3B) : const Color(0xFF2D765C);
  Color get blue => dark ? const Color(0xFF6E8FD0) : const Color(0xFF8FB3E3);
  Color get bird => dark ? const Color(0xFFAAB8B2) : const Color(0xFF4F6B5C);
  Color get wave => dark ? const Color(0xFF10261B) : const Color(0xFFF4F7F5);
}

Paint _fill(Color c, [double opacity = 1]) => Paint()
  ..color = c.withValues(alpha: c.a * opacity)
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;

Paint _stroke(Color c, double w, [double opacity = 1]) => Paint()
  ..color = c.withValues(alpha: c.a * opacity)
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _pine(
    Canvas c, double x, double baseY, double h, Color leaf, Color trunk) {
  final w = h * 0.42;
  c.drawRect(Rect.fromLTWH(x - h * 0.03, baseY - h * 0.16, h * 0.06, h * 0.16),
      _fill(trunk));
  for (var i = 0; i < 3; i++) {
    final top = baseY - h + i * h * 0.24;
    final bottom = top + h * 0.48;
    final half = w * (0.55 + i * 0.22) / 2;
    c.drawPath(
      Path()
        ..moveTo(x, top)
        ..lineTo(x + half, bottom)
        ..lineTo(x - half, bottom)
        ..close(),
      _fill(leaf),
    );
  }
}

Path _hill(Size s, double baseFrac, double amp, double phase, double freq) {
  final p = Path()..moveTo(0, s.height);
  for (var x = 0.0; x <= s.width; x += 4) {
    final y = s.height * baseFrac -
        amp * math.sin((x / s.width) * math.pi * freq + phase);
    p.lineTo(x, y);
  }
  return p
    ..lineTo(s.width, s.height)
    ..close();
}

/// Small art for cards. [kind] picks the drawing; the art sits in the card's corner and
/// is drawn faintly so the text stays readable.
enum CardArt {
  calendar,
  documents,
  hills,
  people,
  fileClaim,
  community,
  checklist
}

class CardArtPainter extends CustomPainter {
  const CardArtPainter(this.kind, {this.dark = false});
  final CardArt kind;
  final bool dark;

  @override
  void paint(Canvas canvas, Size s) {
    final a = _Art(dark);
    switch (kind) {
      case CardArt.calendar:
        _calendar(canvas, s, a);
      case CardArt.documents:
        _documents(canvas, s, a);
      case CardArt.hills:
        _hills(canvas, s, a);
      case CardArt.people:
        _people(canvas, s, a, a.orange);
      case CardArt.fileClaim:
        _fileClaim(canvas, s, a);
      case CardArt.community:
        _people(canvas, s, a, a.green);
        _pine(canvas, s.width * 0.88, s.height * 0.95, s.height * 0.55,
            a.treeLight, a.trunk);
      case CardArt.checklist:
        _checklist(canvas, s, a);
    }
  }

  void _leaves(Canvas c, Offset at, double size, _Art a) {
    for (var i = 0; i < 3; i++) {
      final ang = -0.9 + i * 0.6;
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(ang);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(0, -size * 0.55),
              width: size * 0.38,
              height: size),
          _fill(a.treeLight));
      c.restore();
    }
  }

  void _calendar(Canvas c, Size s, _Art a) {
    final r = Rect.fromLTWH(
        s.width * 0.18, s.height * 0.2, s.width * 0.55, s.height * 0.62);
    _leaves(c, Offset(s.width * 0.18, s.height * 0.9), s.height * 0.4, a);
    _leaves(c, Offset(s.width * 0.82, s.height * 0.92), s.height * 0.35, a);
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)), _fill(a.paper));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)),
        _stroke(a.line, 1.2));
    c.drawRRect(
      RRect.fromRectAndCorners(
          Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.24),
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8)),
      _fill(a.orange),
    );
    for (var i = 0; i < 2; i++) {
      final x = r.left + r.width * (0.3 + i * 0.4);
      c.drawLine(
          Offset(x, r.top - 5), Offset(x, r.top + 6), _stroke(a.treeDark, 2.5));
    }
    final cx = r.center.dx, cy = r.top + r.height * 0.62, d = r.height * 0.18;
    c.drawLine(
        Offset(cx - d, cy - d), Offset(cx + d, cy + d), _stroke(a.red, 2.6));
    c.drawLine(
        Offset(cx + d, cy - d), Offset(cx - d, cy + d), _stroke(a.red, 2.6));
  }

  void _documents(Canvas c, Size s, _Art a) {
    for (var i = 2; i >= 0; i--) {
      final r = Rect.fromLTWH(s.width * (0.22 + i * 0.1),
          s.height * (0.12 + i * 0.06), s.width * 0.5, s.height * 0.72);
      c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(5)), _fill(a.paper));
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)),
          _stroke(a.line, 1.1));
      if (i == 0) {
        for (var l = 0; l < 4; l++) {
          final y = r.top + r.height * (0.25 + l * 0.16);
          c.drawLine(Offset(r.left + 8, y),
              Offset(r.right - 8 - (l.isOdd ? 10 : 0), y), _stroke(a.line, 2));
        }
      }
    }
  }

  void _hills(Canvas c, Size s, _Art a) {
    c.drawPath(
      Path()
        ..moveTo(0, s.height)
        ..lineTo(s.width * 0.35, s.height * 0.25)
        ..lineTo(s.width * 0.55, s.height * 0.6)
        ..lineTo(s.width * 0.72, s.height * 0.35)
        ..lineTo(s.width, s.height)
        ..close(),
      _fill(a.blue),
    );
    c.drawPath(
      Path()
        ..moveTo(s.width * 0.27, s.height * 0.4)
        ..lineTo(s.width * 0.35, s.height * 0.25)
        ..lineTo(s.width * 0.43, s.height * 0.4)
        ..close(),
      _fill(Colors.white, 0.9),
    );
    c.drawPath(_hill(s, 0.92, s.height * 0.05, 0.5, 2.0), _fill(a.midHill));
  }

  void _people(Canvas c, Size s, _Art a, Color tint) {
    for (final (fx, scale) in [(0.3, 0.8), (0.7, 0.8), (0.5, 1.0)]) {
      final x = s.width * fx,
          h = s.height * 0.62 * scale,
          base = s.height * 0.95;
      c.drawCircle(Offset(x, base - h * 0.78), h * 0.2, _fill(tint, 0.85));
      c.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
              center: Offset(x, base - h * 0.25),
              width: h * 0.62,
              height: h * 0.5),
          topLeft: Radius.circular(h * 0.3),
          topRight: Radius.circular(h * 0.3),
        ),
        _fill(tint, 0.85),
      );
    }
  }

  void _fileClaim(Canvas c, Size s, _Art a) {
    final r = Rect.fromLTWH(
        s.width * 0.3, s.height * 0.12, s.width * 0.45, s.height * 0.74);
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)), _fill(a.paper));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
        _stroke(a.line, 1.1));
    for (var l = 0; l < 3; l++) {
      final y = r.top + r.height * (0.3 + l * 0.18);
      c.drawLine(
          Offset(r.left + 8, y), Offset(r.right - 8, y), _stroke(a.line, 2));
    }
    _leaves(c, Offset(s.width * 0.82, s.height * 0.95), s.height * 0.45, a);
  }

  void _checklist(Canvas c, Size s, _Art a) {
    final r = Rect.fromLTWH(
        s.width * 0.3, s.height * 0.14, s.width * 0.45, s.height * 0.76);
    c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)), _fill(a.paper));
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
        _stroke(a.line, 1.1));
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(r.center.dx, r.top),
              width: r.width * 0.45,
              height: 8),
          const Radius.circular(3)),
      _fill(a.treeDark),
    );
    for (var l = 0; l < 3; l++) {
      final y = r.top + r.height * (0.3 + l * 0.22);
      final x = r.left + 10;
      c.drawPath(
        Path()
          ..moveTo(x - 3, y)
          ..lineTo(x, y + 3)
          ..lineTo(x + 5, y - 4),
        _stroke(a.green, 2),
      );
      c.drawLine(Offset(x + 10, y), Offset(r.right - 8, y), _stroke(a.line, 2));
    }
  }

  @override
  bool shouldRepaint(CardArtPainter old) =>
      old.kind != kind || old.dark != dark;
}
