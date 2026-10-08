import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'bottom_nav_bar.dart' show AppTab;

/// Animated bottom navigation bar with:
/// - Sliding pill indicator under the active tab
/// - Subtle icon scale bounce on selection
/// - Smooth color transitions on label and icon
///
/// Drop-in replacement for the original BottomNavBar — same API surface.
class AnimatedBottomNavBar extends StatefulWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab>? onTabSelected;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentTab,
    this.onTabSelected,
  });

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  static const List<_NavItemData> _items = [
    _NavItemData(
      tab: AppTab.dashboard,
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
    ),
    _NavItemData(
      tab: AppTab.claims,
      label: 'Claims',
      icon: Icons.folder_shared_outlined,
      activeIcon: Icons.folder_shared_rounded,
    ),
    _NavItemData(
      tab: AppTab.profile,
      label: 'Profile',
      icon: Icons.account_circle_outlined,
      activeIcon: Icons.account_circle_rounded,
    ),
    _NavItemData(
      tab: AppTab.sabha,
      label: 'Gram Sabha',
      icon: Icons.how_to_vote_outlined,
      activeIcon: Icons.how_to_vote_rounded,
    ),
    _NavItemData(
      tab: AppTab.map,
      label: 'Atlas Map',
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _anim = Tween<double>(
      begin: widget.currentTab.index.toDouble(),
      end: widget.currentTab.index.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(AnimatedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab != widget.currentTab) {
      _anim = Tween<double>(
        begin: _anim.value,
        end: widget.currentTab.index.toDouble(),
      ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNav(AppTab tab) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(tab);
      return;
    }
    if (tab == widget.currentTab) return;

    switch (tab) {
      case AppTab.dashboard:
        Navigator.pushReplacementNamed(context, AppRouter.villagerHome);
        break;
      case AppTab.claims:
        Navigator.pushNamed(context, AppRouter.myClaims);
        break;
      case AppTab.sabha:
        Navigator.pushNamed(context, AppRouter.gramSabhaDashboard);
        break;
      case AppTab.map:
        Navigator.pushNamed(context, AppRouter.boundaryMap);
        break;
      case AppTab.profile:
        Navigator.pushNamed(context, AppRouter.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final tabWidth = width / 5;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Background Notched Pill
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _NavCurvePainter(
                        animValue: _anim.value,
                        bgColor: c.navBg,
                        borderColor: c.navBorder.withValues(alpha: 0.5),
                        borderWidth: isDark ? 1.0 : 0.5,
                        isDark: isDark,
                      ),
                      size: Size(width, 68),
                    );
                  },
                ),

                // Floating Circular Bubble
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, child) {
                    return Positioned(
                      top: -24,
                      left: tabWidth * (_anim.value + 0.5) - 28,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.saffron,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.saffron.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.white24,
                            width: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Navigation Items
                SizedBox(
                  height: 68,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _items.map((item) {
                      final isSelected = widget.currentTab == item.tab;
                      return Expanded(
                        child: _AnimatedNavItem(
                          data: item,
                          isSelected: isSelected,
                          onTap: () => _handleNav(item.tab),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItemData {
  final AppTab tab;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItemData({
    required this.tab,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _NavCurvePainter extends CustomPainter {
  final double animValue;
  final Color bgColor;
  final Color borderColor;
  final double borderWidth;
  final bool isDark;

  _NavCurvePainter({
    required this.animValue,
    required this.bgColor,
    required this.borderColor,
    required this.borderWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final host = Offset.zero & size;
    final notchCenterX = size.width * (animValue + 0.5) / 5;
    final guest = Rect.fromCircle(center: Offset(notchCenterX, 4), radius: 34);

    final shape = AutomaticNotchedShape(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      const CircleBorder(),
    );
    final path = shape.getOuterPath(host, guest);

    // Draw shadow
    canvas.drawShadow(path, isDark ? Colors.black : const Color(0xFF1B4332),
        isDark ? 12 : 8, true);

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bgPaint);

    if (borderWidth > 0) {
      final borderPaint = Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NavCurvePainter old) {
    return old.animValue != animValue ||
        old.bgColor != bgColor ||
        old.borderColor != borderColor ||
        old.borderWidth != borderWidth ||
        old.isDark != isDark;
  }
}

class _AnimatedNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isActive = isSelected;
    final iconColor = isActive ? Colors.white : c.navUnselected;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            top: isActive ? -10 : 14,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isActive ? data.activeIcon : data.icon,
                key: ValueKey(isActive),
                color: iconColor,
                size: 28,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: AppTypography.caption.copyWith(
                color: isActive ? AppColors.saffron : c.navUnselected,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: isActive ? 10.5 : 10,
              ),
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
