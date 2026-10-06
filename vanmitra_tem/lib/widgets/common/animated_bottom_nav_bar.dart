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
class AnimatedBottomNavBar extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab>? onTabSelected;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentTab,
    this.onTabSelected,
  });

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
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 32),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Background Notched Pill
            CustomPaint(
              painter: _NavCurvePainter(
                bgColor: c.navBg,
                borderColor: c.navBorder.withValues(alpha: 0.5),
                borderWidth: isDark ? 1.0 : 0.5,
                isDark: isDark,
              ),
              child: SizedBox(
                height: 68,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _items.map((item) {
                    final isSelected = currentTab == item.tab;
                    if (item.tab == AppTab.profile) {
                      return const SizedBox(width: 76); // Spacer for center notch
                    }
                    return Expanded(
                      child: _AnimatedNavItem(
                        data: item,
                        isSelected: isSelected,
                        onTap: () => _handleNav(context, item.tab),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // Center Floating Profile Button
            Positioned(
              top: -24,
              child: _CenterProfileButton(
                data: _items.firstWhere((i) => i.tab == AppTab.profile),
                isSelected: currentTab == AppTab.profile,
                onTap: () => _handleNav(context, AppTab.profile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNav(BuildContext context, AppTab tab) {
    if (onTabSelected != null) {
      onTabSelected!(tab);
      return;
    }

    if (tab == currentTab) return;

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
  final Color bgColor;
  final Color borderColor;
  final double borderWidth;
  final bool isDark;

  _NavCurvePainter({
    required this.bgColor,
    required this.borderColor,
    required this.borderWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final host = Offset.zero & size;
    final guest = Rect.fromCircle(center: Offset(size.width / 2, 4), radius: 34);
    
    final shape = AutomaticNotchedShape(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      const CircleBorder(),
    );
    final path = shape.getOuterPath(host, guest);

    // Draw shadow
    canvas.drawShadow(path, isDark ? Colors.black : const Color(0xFF1B4332), isDark ? 12 : 8, true);

    final bgPaint = Paint()..color = bgColor..style = PaintingStyle.fill;
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
    return old.bgColor != bgColor ||
           old.borderColor != borderColor ||
           old.borderWidth != borderWidth ||
           old.isDark != isDark;
  }
}

class _CenterProfileButton extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterProfileButton({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;
    
    final bgColor = isSelected 
        ? AppColors.saffron 
        : (isDark ? const Color(0xFF2A3A32) : AppColors.forestCanopy);
        
    final iconColor = Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.white24,
                width: 1,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isSelected ? data.activeIcon : data.icon,
                  key: ValueKey(isSelected),
                  color: iconColor,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: AppTypography.caption.copyWith(
              color: isSelected ? AppColors.saffron : c.navUnselected,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: isSelected ? 10.5 : 10,
            ),
            child: Text(data.label, maxLines: 1, overflow: TextOverflow.visible),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(_AnimatedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _bounceController.forward(from: 0);
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isActive = widget.isSelected;
    final unselectedColor = c.navUnselected;
    final selectedColor = AppColors.saffron;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: double.infinity,
        child: AnimatedBuilder(
          animation: _bounceController,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: _bounceController.isAnimating ? _scaleAnimation.value : 1.0,
                  child: Icon(
                    isActive ? widget.data.activeIcon : widget.data.icon,
                    color: isActive ? selectedColor : unselectedColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: AppTypography.caption.copyWith(
                    color: isActive ? selectedColor : unselectedColor,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: isActive ? 10.5 : 10,
                  ),
                  child: Text(widget.data.label, maxLines: 1, overflow: TextOverflow.visible),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
