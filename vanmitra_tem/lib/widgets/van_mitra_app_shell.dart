import 'package:flutter/material.dart';
import '../core/routes/app_router.dart';
import '../core/theme/app_colors.dart';

// ── Design Tokens (Unified with AppColors & Forest Canopy Theme) ───────────
const kPrimary = AppColors.forestCanopy;
const kPrimaryContainer = AppColors.forestSage;
const kOnPrimary = AppColors.textOnBrand;
const kOnPrimaryContainer = AppColors.surfaceCard;
const kSurface = AppColors.surfaceBase;
const kSurfaceWhite = AppColors.surfaceCard;
const kSurfaceContainerHighest = AppColors.divider;
const kSurfaceContainerHigh = AppColors.surfaceSunken;
const kSurfaceContainerLow = AppColors.surfaceBase;
const kSurfaceContainer = AppColors.surfaceSunken;
const kOnSurface = AppColors.textPrimary;
const kOnSurfaceVariant = AppColors.textSecondary;
const kOutlineVariant = AppColors.divider;
const kStatusSuccess = AppColors.successGreen;
const kStatusWarning = AppColors.warningAmber;
const kStatusError = AppColors.alertRed;
const kErrorContainer = Color(0xFFFFDAD6);
const kSecondaryContainer = AppColors.saffron;
const kOnSecondaryContainer = AppColors.textOnBrand;
const kTertiaryFixed = Color(0xFFE0E0FF);
const kOnTertiaryFixed = Color(0xFF00006E);
const kSecondaryFixed = Color(0xFFFFDCC2);
const kOnSecondaryFixed = Color(0xFF2E1500);
const kPrimaryFixedDim = AppColors.forestMist;

/// Which bottom-nav tab is active on this screen.
enum VanMitraTab { home, claims, map, ledger, profile }

// ── Top App Bar ─────────────────────────────────────────────────────────────

/// Shared header: [🏛 account_balance] VanMitra-AI [🌐 language]
/// Matches the design reference across all 3 screens.
class VanMitraTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;

  const VanMitraTopBar({super.key, this.showBack = false});

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final titleColor = c.isDark ? AppColors.forestMist : kPrimary;
    final headerBg = c.isDark ? c.surface : kSurfaceContainerHighest;

    return Container(
      color: headerBg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              // Left: emblem or back
              if (showBack)
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: titleColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
              else
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(Icons.account_balance, color: titleColor, size: 24),
                  ),
                ),

              // Center: title
              Expanded(
                child: Text(
                  'VanMitra-AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    fontFamily: 'NotoSans',
                  ),
                ),
              ),

              // Right: language icon
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(Icons.language, color: titleColor, size: 24),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ────────────────────────────────────────────────────

/// Shared bottom navigation bar: Home | Claims | Map | Ledger | Profile
/// Active tab shows an accent pill background.
class VanMitraBottomNav extends StatelessWidget {
  final VanMitraTab activeTab;

  const VanMitraBottomNav({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: c.navBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Home',
                isActive: activeTab == VanMitraTab.home,
                onTap: () => _go(context, AppRouter.villagerHome),
              ),
              _NavItem(
                icon: Icons.description_outlined,
                activeIcon: Icons.description,
                label: 'Claims',
                isActive: activeTab == VanMitraTab.claims,
                onTap: () => _go(context, AppRouter.myClaims),
              ),
              _NavItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Map',
                isActive: activeTab == VanMitraTab.map,
                onTap: () => _go(context, AppRouter.boundaryMap),
              ),
              _NavItem(
                icon: Icons.history_edu_outlined,
                activeIcon: Icons.history_edu,
                label: 'Ledger',
                isActive: activeTab == VanMitraTab.ledger,
                onTap: () => _go(context, AppRouter.resolutionLedger),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: activeTab == VanMitraTab.profile,
                onTap: () => _go(context, AppRouter.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final itemColor = isActive ? c.navSelected : c.navUnselected;
    final activeBg = c.isDark
        ? AppColors.saffron.withValues(alpha: 0.16)
        : kPrimaryContainer;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: activeBg,
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: itemColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
