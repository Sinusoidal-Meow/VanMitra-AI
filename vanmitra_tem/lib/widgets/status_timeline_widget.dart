import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// DBT-style horizontal status timeline widget.
///
/// Reused for:
///   1. Claim tracking (4 steps): प्राप्त → पडताळणी → ग्रामसभा शिफारस → मंजूर/नामंजूर
///   2. Multi-step claim form (5 steps): दावेदार माहिती → जमीन → ताबा → पुरावा → पुनरावलोकन
///
/// Completed steps → green tick; current step → pulsing saffron; future → grey.
class StatusTimelineWidget extends StatefulWidget {
  final List<String> steps;
  final int currentStep; // 0-indexed
  final bool isRejected; // paints final step red if true

  const StatusTimelineWidget({
    super.key,
    required this.steps,
    required this.currentStep,
    this.isRejected = false,
  });

  @override
  State<StatusTimelineWidget> createState() => _StatusTimelineWidgetState();
}

class _StatusTimelineWidgetState extends State<StatusTimelineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          // ── Step circles + connector lines ─────────────────────────────────
          Row(
            children: [
              for (int i = 0; i < widget.steps.length; i++) ...[
                _buildStepCircle(context, i),
                if (i < widget.steps.length - 1) _buildConnector(context, i),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // ── Step labels ───────────────────────────────────────────────────
          Row(
            children: [
              for (int i = 0; i < widget.steps.length; i++) ...[
                Expanded(
                  child: Text(
                    widget.steps[i],
                    style: TextStyle(
                      fontFamily: 'NotoSansDevanagari',
                      fontSize: 9,
                      color: _labelColor(context, i),
                      fontWeight: i == widget.currentStep
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(BuildContext context, int i) {
    final c = context.colors;
    final isDone = i < widget.currentStep;
    final isCurrent = i == widget.currentStep;
    final isLast = i == widget.steps.length - 1;

    Color circleColor;
    Widget child;

    if (isDone) {
      circleColor = AppColors.successGreen;
      child = const Icon(Icons.check_rounded, color: Colors.white, size: 12);
    } else if (isCurrent) {
      circleColor = (isLast && widget.isRejected)
          ? AppColors.alertRed
          : AppColors.accentSaffron;
      child = Text(
        '${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      circleColor = c.isDark ? c.sunkenBg : const Color(0xFFCBD5E1);
      child = Text(
        '${i + 1}',
        style: TextStyle(
          color: c.isDark ? c.textTertiary : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final circle = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: circleColor,
        border: (c.isDark && !isDone && !isCurrent)
            ? Border.all(color: c.border.withValues(alpha: 0.5))
            : null,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: circleColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Center(child: child),
    );

    if (isCurrent) {
      return AnimatedBuilder(
        animation: _scaleAnim,
        builder: (ctx, _) =>
            Transform.scale(scale: _scaleAnim.value, child: circle),
      );
    }
    return circle;
  }

  Widget _buildConnector(BuildContext context, int i) {
    final c = context.colors;
    final isCompleted = i < widget.currentStep - 1 ||
        (i == widget.currentStep - 1);
    final inactiveLineColor = c.isDark ? c.border : const Color(0xFFCBD5E1);

    return Expanded(
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: isCompleted
              ? const LinearGradient(
                  colors: [AppColors.successGreen, AppColors.successGreen],
                )
              : LinearGradient(
                  colors: [inactiveLineColor, inactiveLineColor],
                ),
        ),
      ),
    );
  }

  Color _labelColor(BuildContext context, int i) {
    final c = context.colors;
    if (i < widget.currentStep) return AppColors.successGreen;
    if (i == widget.currentStep) {
      return (i == widget.steps.length - 1 && widget.isRejected)
          ? AppColors.alertRed
          : AppColors.accentSaffron;
    }
    return c.isDark ? c.textTertiary : const Color(0xFF94A3B8);
  }
}
