import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'animated_counter.dart';

/// Data model representing a statistic metric inside the [StatisticCardStack].
class StatisticCardItem {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatisticCardItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.onTap,
  });
}

/// A focused Tinder-style swipeable card stack for VanMitra-AI Dashboard statistics.
///
/// Features:
/// - One primary focused card in front with prominent typography, counter, and depth.
/// - Remaining statistic cards partially visible behind it with layered offset and scale.
/// - Real-time gesture interpolation: active card follows the user's finger,
///   while cards behind it dynamically lerp forward in the stack.
/// - Velocity and distance-aware dismiss (left/right swipe) with spring-back physics.
/// - Interactive indicator pill row below the stack for instant card jumping.
/// - Full Light and Dark theme responsiveness and zero dependencies.
class StatisticCardStack extends StatefulWidget {
  final List<StatisticCardItem> items;
  final double cardHeight;
  final ValueChanged<int>? onIndexChanged;

  const StatisticCardStack({
    super.key,
    required this.items,
    this.cardHeight = 126.0,
    this.onIndexChanged,
  });

  @override
  State<StatisticCardStack> createState() => _StatisticCardStackState();
}

class _StatisticCardStackState extends State<StatisticCardStack>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  int? _targetIndex;
  bool _isAnimating = false;

  late final AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnimation = const AlwaysStoppedAnimation(Offset.zero);

    _animController.addListener(() {
      setState(() {
        _dragOffset = _slideAnimation.value;
      });
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_targetIndex != null) {
          setState(() {
            _currentIndex = _targetIndex!;
            _dragOffset = Offset.zero;
            _isAnimating = false;
            _targetIndex = null;
          });
          widget.onIndexChanged?.call(_currentIndex);
        } else {
          setState(() {
            _dragOffset = Offset.zero;
            _isAnimating = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isAnimating || widget.items.isEmpty) return;
    setState(() {
      _dragOffset += Offset(details.delta.dx, 0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isAnimating || widget.items.isEmpty) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final velocityX = details.primaryVelocity ?? 0.0;
    final dx = _dragOffset.dx;

    // Threshold: either dragged > 80px or fling velocity > 500px/s
    final bool isDismissLeft = dx < -80 || velocityX < -500;
    final bool isDismissRight = dx > 80 || velocityX > 500;

    if (isDismissLeft) {
      // Swiped Left: advance to next card (Total Claims -> Meetings -> Resolutions -> Members)
      _animateDismiss(
        targetOffset: Offset(-screenWidth * 1.25, _dragOffset.dy),
        nextIndex: (_currentIndex + 1) % widget.items.length,
      );
    } else if (isDismissRight) {
      // Swiped Right: cycle to previous card
      _animateDismiss(
        targetOffset: Offset(screenWidth * 1.25, _dragOffset.dy),
        nextIndex: (_currentIndex - 1 + widget.items.length) % widget.items.length,
      );
    } else {
      // Release below threshold -> snap back cleanly
      _animateSnapBack();
    }
  }

  void _animateDismiss({required Offset targetOffset, required int nextIndex}) {
    _isAnimating = true;
    _targetIndex = nextIndex;
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
  }

  void _animateSnapBack() {
    _isAnimating = true;
    _targetIndex = null;
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    _animController.forward(from: 0.0);
  }

  void _jumpTo(int index) {
    if (_isAnimating || index == _currentIndex || widget.items.isEmpty) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final direction = index > _currentIndex ? -1.0 : 1.0;
    _animateDismiss(
      targetOffset: Offset(direction * screenWidth * 1.25, 0),
      nextIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final c = context.colors;
    final len = widget.items.length;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Normalized progress p in [0.0, 1.0] for positional interpolation
    final maxDrag = screenWidth * 0.7;
    final p = (_dragOffset.dx.abs() / maxDrag).clamp(0.0, 1.0);

    // Layer 0: Front/Active Card
    final layer0Index = _currentIndex;
    final rotation = (_dragOffset.dx / screenWidth) * 0.10; // Max ~3 degrees subtle tilt
    final scale0 = 1.0 - (0.02 * p);
    final opacity0 = (1.0 - (p * 0.40)).clamp(0.0, 1.0);

    // Layer 1: First card behind
    final layer1Index = (len > 1) ? (_currentIndex + 1) % len : null;
    final scale1 = 0.94 + (0.06 * p);
    final offsetY1 = -11.0 + (11.0 * p);
    final opacity1 = 0.82 + (0.18 * p);

    // Layer 2: Second card behind
    final layer2Index = (len > 2) ? (_currentIndex + 2) % len : null;
    final scale2 = 0.88 + (0.06 * p);
    final offsetY2 = -20.0 + (9.0 * p);
    final opacity2 = 0.60 + (0.22 * p);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card Stack Area ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 22.0),
          child: SizedBox(
            height: widget.cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Layer 2 (Bottom card)
                if (layer2Index != null)
                  _buildStackedCard(
                    item: widget.items[layer2Index],
                    scale: scale2,
                    offsetY: offsetY2,
                    opacity: opacity2,
                  ),

                // Layer 1 (Middle card)
                if (layer1Index != null)
                  _buildStackedCard(
                    item: widget.items[layer1Index],
                    scale: scale1,
                    offsetY: offsetY1,
                    opacity: opacity1,
                  ),

                // Layer 0 (Focused Front card with gesture interaction)
                _buildFrontCard(
                  item: widget.items[layer0Index],
                  translateX: _dragOffset.dx,
                  rotation: rotation,
                  scale: scale0,
                  opacity: opacity0,
                  itemNumber: layer0Index + 1,
                  totalItems: len,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm + 2),

        // ── Interactive Stack Indicator Pills ────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(len, (i) {
            final isActive = i == _currentIndex;
            final itemColor = widget.items[i].iconColor;
            return GestureDetector(
              onTap: () => _jumpTo(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                width: isActive ? 26 : 7,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? itemColor
                      : c.border.withValues(alpha: c.isDark ? 0.45 : 0.70),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: itemColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Build partially visible background card in the stack ───────────────────
  Widget _buildStackedCard({
    required StatisticCardItem item,
    required double scale,
    required double offsetY,
    required double opacity,
  }) {
    final c = context.colors;
    return Positioned(
      top: offsetY,
      left: 0,
      right: 0,
      height: widget.cardHeight,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: c.border.withValues(alpha: c.isDark ? 0.55 : 0.40),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : const Color(0x0C0F172A),
                  offset: const Offset(0, 3),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: item.iconColor.withValues(alpha: c.isDark ? 0.04 : 0.06),
                  offset: const Offset(0, 6),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build interactive focused front card ───────────────────────────────────
  Widget _buildFrontCard({
    required StatisticCardItem item,
    required double translateX,
    required double rotation,
    required double scale,
    required double opacity,
    required int itemNumber,
    required int totalItems,
  }) {
    final c = context.colors;
    final displayValue = (item.value == '-' || item.value.isEmpty) ? '0' : item.value;
    final numericValue = int.tryParse(displayValue);

    final cardContent = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: c.border.withValues(alpha: c.isDark ? 0.65 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          // Primary clean shadow
          BoxShadow(
            color: c.isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0x120F172A),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
          // Accent colored ambient glow matching metric
          BoxShadow(
            color: item.iconColor.withValues(alpha: c.isDark ? 0.08 : 0.12),
            offset: const Offset(0, 8),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top Row: Metric Icon + Title + Stack Position Chip ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gradient rounded icon badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.iconColor.withValues(alpha: c.isDark ? 0.25 : 0.15),
                      item.iconColor.withValues(alpha: c.isDark ? 0.12 : 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.iconColor.withValues(alpha: c.isDark ? 0.35 : 0.20),
                    width: 1,
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: item.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title and context hint
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: AppTypography.subtitle.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: c.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle ?? 'Tap to view details',
                      style: AppTypography.caption.copyWith(
                        color: c.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Stack index pill (e.g. 1/4)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.iconColor.withValues(alpha: c.isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item.iconColor.withValues(alpha: c.isDark ? 0.30 : 0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$itemNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: item.iconColor,
                      ),
                    ),
                    Text(
                      '/$totalItems',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Bottom Row: Large Metric Counter + Action Chevron ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Value / Animated counter
              numericValue != null
                  ? AnimatedCounter(
                      targetValue: numericValue,
                      duration: const Duration(milliseconds: 1100),
                      style: AppTypography.stat.copyWith(
                        fontSize: 28,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: c.statNumber,
                        letterSpacing: -0.5,
                      ),
                    )
                  : Text(
                      displayValue,
                      style: AppTypography.stat.copyWith(
                        fontSize: 28,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: c.statNumber,
                        letterSpacing: -0.5,
                      ),
                    ),

              // Action link cue
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Swipe',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.textTertiary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: widget.cardHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isAnimating) {
            item.onTap?.call();
          }
        },
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Transform.translate(
          offset: Offset(translateX, math.sin((translateX.abs() / 200).clamp(0.0, 1.0) * math.pi) * 3),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: cardContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
