import 'package:flutter/material.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

enum AppTab { dashboard, claims, profile, sabha, map }

/// Universal BottomNavBar featuring Saffron fill active icons for sunlight legibility
/// and consistent 5-tab architectural navigation.
class BottomNavBar extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab>? onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.isDark;

    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x140F172A),
            offset: const Offset(0, -2),
            blurRadius: 8,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavTabItem(
                title: 'Dashboard',
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                isSelected: currentTab == AppTab.dashboard,
                onTap: () => _handleNav(context, AppTab.dashboard),
              ),
              _NavTabItem(
                title: 'Claims',
                icon: Icons.folder_shared_outlined,
                activeIcon: Icons.folder_shared_rounded,
                isSelected: currentTab == AppTab.claims,
                onTap: () => _handleNav(context, AppTab.claims),
              ),
              _NavTabItem(
                title: 'Gram Sabha',
                icon: Icons.how_to_vote_outlined,
                activeIcon: Icons.how_to_vote_rounded,
                isSelected: currentTab == AppTab.sabha,
                onTap: () => _handleNav(context, AppTab.sabha),
              ),
              _NavTabItem(
                title: 'Atlas Map',
                icon: Icons.map_outlined,
                activeIcon: Icons.map_rounded,
                isSelected: currentTab == AppTab.map,
                onTap: () => _handleNav(context, AppTab.map),
              ),
              _NavTabItem(
                title: 'Profile',
                icon: Icons.account_circle_outlined,
                activeIcon: Icons.account_circle_rounded,
                isSelected: currentTab == AppTab.profile,
                onTap: () => _handleNav(context, AppTab.profile),
              ),
            ],
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

class _NavTabItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = isSelected ? c.navSelected : c.navUnselected;
    final bg = isSelected
        ? (c.isDark
            ? AppColors.saffron.withValues(alpha: 0.16)
            : AppColors.saffron.withValues(alpha: 0.12))
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
