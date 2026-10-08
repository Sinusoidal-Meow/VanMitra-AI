import 'dart:ui';
import 'package:flutter/material.dart';

class VanMitraBackgroundWatermark extends StatelessWidget {
  final double opacity;
  final double blurSigma;
  final Alignment alignment;
  final double widthFactor; // percentage of screen width

  const VanMitraBackgroundWatermark({
    super.key,
    this.opacity = 0.09,
    this.blurSigma = 2.0,
    this.alignment = const Alignment(0, 0.25),
    this.widthFactor = 0.58,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Opacity(
          opacity: opacity,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Image.asset(
              'assets/images/vanmitra_logo.png',
              width: screenWidth * widthFactor,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
