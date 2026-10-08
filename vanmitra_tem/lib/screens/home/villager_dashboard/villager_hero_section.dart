// The villager hero: dark green background with the existing S-curve, separate nature
// layers clipped to the green area, and the frosted-glass profile card in front.
//
//   Stack
//    ├── DashboardCurveBackground   (green base + S-curve, behind everything)
//    ├── nature layers, clipped to the green: hills, tree line, sun, village, birds, leaves
//    └── content (child): the glass profile card, then the rest of the dashboard

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../widgets/common/dashboard_curve_background.dart';
import 'hero_nature_layers.dart';

/// Geometry of the hero (logical pixels from the top of the scrolling content).
class HeroGeometry {
  static const cardTop = 14.0;
  static const cardHeight = 128.0;
  static const curveStart = 192.0; // the curve leaves the left edge here
  static const curveDrop = 0.10; // × width: a long, gentle horizontal flow
  static const contentTop = 200.0; // where the Next Meeting card begins
}

/// Hero background plus [child] (the dashboard content) layered in front of it.
class VillagerHeroSection extends StatelessWidget {
  const VillagerHeroSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            const DashboardCurveBackground(
              startY: HeroGeometry.curveStart,
              dropFactor: HeroGeometry.curveDrop,
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: HeroGeometry.curveStart + w * HeroGeometry.curveDrop,
              child: ClipPath(
                clipper: const DashboardCurveClipper(
                  startY: HeroGeometry.curveStart,
                  dropFactor: HeroGeometry.curveDrop,
                ),
                child: _NatureLayers(width: w),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _NatureLayers extends StatelessWidget {
  const _NatureLayers({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    final w = width;
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Layer E: the sun sits low on the right, partly behind the hills.
        Positioned(
            left: w * 0.74,
            top: 128,
            width: 26,
            height: 26,
            child: const HeroSun()),
        // Layer B: distant hills toward the bottom of the green.
        Positioned(
            left: 0,
            right: 0,
            top: 112,
            height: 80 + w * HeroGeometry.curveDrop,
            child: const HeroHills()),
        // Layer C: a distant tree line on the far hills.
        const Positioned(
            left: 0, right: 0, top: 112, height: 34, child: HeroTreeLine()),
        // Layer D: a very small village to the right.
        Positioned(
            left: w * 0.62,
            top: 140,
            width: 22,
            height: 18,
            child: const HeroVillage()),
        // Layer F: a few birds in the open sky below the card.
        Positioned(
            left: w * 0.30,
            top: 146,
            width: 90,
            height: 24,
            child: const HeroBirds()),
        // Layer A: leaves framing the left and right edges, partly cut off.
        const Positioned(
            left: -22, top: 34, width: 74, height: 150, child: HeroLeaves()),
        const Positioned(
            right: -18,
            top: -6,
            width: 66,
            height: 130,
            child: HeroLeaves(mirrored: true)),
      ],
    );
  }
}

/// The user's identity on frosted glass: the landscape stays faintly visible through it.
class VillagerGlassProfileCard extends StatelessWidget {
  const VillagerGlassProfileCard({
    super.key,
    required this.userName,
    required this.roleLabel,
    required this.place,
    this.onProfileTap,
    this.onEmblemTap,
  });

  final String userName;
  final String roleLabel;
  final String place;
  final VoidCallback? onProfileTap;
  final VoidCallback? onEmblemTap;

  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    final name = userName.trim().isEmpty ? 'VanMitra Citizen' : userName.trim();
    return Container(
      height: HeroGeometry.cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          // Blur only this card's backdrop.
          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              // Mostly transparent: a light frost, brighter at the top-left.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              // Soft inner highlight along the top edge.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.transparent
                ],
              ),
            ),
            child: Row(
              children: [
                _Avatar(name: name, onTap: onProfileTap),
                const SizedBox(width: 14),
                Expanded(
                    child: _Identity(
                        name: name, roleLabel: roleLabel, place: place)),
                _Emblem(onTap: onEmblemTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.onTap});
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9A2E), Color(0xFFFF8A00)],
          ),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF8A00).withValues(alpha: 0.45),
                blurRadius: 14),
          ],
        ),
        child: Text(
          name.characters.first.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity(
      {required this.name, required this.roleLabel, required this.place});
  final String name;
  final String roleLabel;
  final String place;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Hello, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E705B).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                roleLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.location_on, size: 14, color: Color(0xFFCFE7D6)),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: Color(0xFFCFE7D6), fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child:
            const Icon(Icons.spa_rounded, size: 20, color: Color(0xFFCFE7D6)),
      ),
    );
  }
}
