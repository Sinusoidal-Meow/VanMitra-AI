import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable tactile press wrapper that provides a subtle scale-down effect
/// (0.97 scale) with an elastic spring-back on tap down/up.
///
/// Wrap any card or list item to give it premium "pressed" feedback:
/// ```dart
/// BouncingCard(
///   onTap: () => doSomething(),
///   child: MyCardContent(),
/// )
/// ```
class BouncingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Scale factor when pressed. Default 0.97 gives a subtle, premium feel.
  final double pressedScale;

  /// Whether to trigger light haptic feedback on tap down.
  final bool hapticFeedback;

  const BouncingCard({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
    this.hapticFeedback = true,
  });

  @override
  State<BouncingCard> createState() => _BouncingCardState();
}

class _BouncingCardState extends State<BouncingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    if (widget.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
