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
    _NavItemData(
      tab: AppTab.profile,
      label: 'Profile',
      icon: Icons.account_circle_outlined,
      activeIcon: Icons.account_circle_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;

    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x1A1B4332),
            offset: const Offset(0, -3),
            blurRadius: 12,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: c.navBorder,
            width: isDark ? 1.0 : 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.map((item) {
              return _AnimatedNavItem(
                data: item,
                isSelected: currentTab == item.tab,
                onTap: () => _handleNav(context, item.tab),
              );
            }).toList(),
          ),
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

/// Individual animated nav item with:
/// - Icon scale bounce on selection (1.0 → 1.2 → 1.0 spring)
/// - Sliding pill background indicator
/// - Smooth color crossfade
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
    with TickerProviderStateMixin {
  late final AnimationController _selectionController;
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _pillWidthAnimation;
  late final Animation<double> _pillOpacityAnimation;

  @override
  void initState() {
    super.initState();

    // Selection state animation (pill + color)
    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Bounce animation (icon scale)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_bounceController);

    _pillWidthAnimation = Tween<double>(begin: 0, end: 48).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pillOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _selectionController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    if (widget.isSelected) {
      _selectionController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _selectionController.forward();
      _bounceController.forward(from: 0);
      HapticFeedback.selectionClick();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _selectionController.reverse();
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: AnimatedBuilder(
          animation:
              Listenable.merge([_selectionController, _bounceController]),
          builder: (context, child) {
            final c = context.colors;
            final isDark = c.isDark;
            final isActive = widget.isSelected;
            final unselectedColor = c.navUnselected;
            final selectedColor = c.navSelected;
            final color = Color.lerp(
              unselectedColor,
              selectedColor,
              _selectionController.value,
            )!;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouncing icon
                Transform.scale(
                  scale: _bounceController.isAnimating
                      ? _scaleAnimation.value
                      : 1.0,
                  child: Icon(
                    isActive ? widget.data.activeIcon : widget.data.icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 2),

                // Label with smooth crossfade
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: AppTypography.caption.copyWith(
                    color: isActive
                        ? selectedColor
                        : unselectedColor,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: isActive ? 10.5 : 10,
                  ),
                  child: Text(widget.data.label),
                ),
                const SizedBox(height: 3),

                // Sliding pill indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: _pillWidthAnimation.value,
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              AppColors.saffron
                                  .withValues(alpha: _pillOpacityAnimation.value),
                              AppColors.secondaryLight.withValues(
                                  alpha: _pillOpacityAnimation.value * 0.8),
                            ]
                          : [
                              AppColors.forestCanopy
                                  .withValues(alpha: _pillOpacityAnimation.value),
                              AppColors.forestSage.withValues(
                                  alpha: _pillOpacityAnimation.value * 0.8),
                            ],
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: (isDark ? AppColors.saffron : AppColors.forestCanopy)
                                  .withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
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
