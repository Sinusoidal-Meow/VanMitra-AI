import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

/// Smooth count-up animation widget that tweens from 0 to a target integer value.
///
/// Used in StatTile KPI metrics to create an engaging "rolling counter" effect
/// when the dashboard first loads.
///
/// ```dart
/// AnimatedCounter(
///   targetValue: 500,
///   duration: Duration(milliseconds: 1200),
///   style: AppTypography.stat,
/// )
/// ```
class AnimatedCounter extends StatelessWidget {
  final int targetValue;
  final Duration duration;
  final TextStyle? style;
  final Curve curve;
  final String? prefix;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.targetValue,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.curve = Curves.easeOutCubic,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final displayValue = value.toInt().toString();
        return Text(
          '${prefix ?? ''}$displayValue${suffix ?? ''}',
          style: style ?? AppTypography.stat.copyWith(fontSize: 22, height: 1.1),
          maxLines: 1,
        );
      },
    );
  }
}
