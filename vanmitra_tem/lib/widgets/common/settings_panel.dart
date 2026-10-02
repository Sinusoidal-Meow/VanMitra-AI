import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// A sliding-down settings panel that appears beneath the AppHeader on tap.
///
/// Features:
/// - Animated slide-down + fade-in reveal
/// - Profile row (avatar, name, role, → navigate to profile screen)
/// - Theme toggle row with a custom animated light/dark pill switch
/// - Tapping outside / pressing the trigger again collapses the panel
///
/// Usage — keep a [GlobalKey<SettingsPanelState>] and call [toggle()] from the
/// header button, or use [SettingsPanelController] below.
class SettingsPanel extends ConsumerStatefulWidget {
  const SettingsPanel({super.key});

  @override
  ConsumerState<SettingsPanel> createState() => SettingsPanelState();
}

class SettingsPanelState extends ConsumerState<SettingsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;
  late final Animation<double> _opacity;

  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Toggle open/closed — call this from the AppHeader settings button.
  void toggle() {
    if (_isOpen) {
      _controller.reverse().then((_) => setState(() => _isOpen = false));
    } else {
      setState(() => _isOpen = true);
      _controller.forward();
    }
  }

  /// Close without toggle — useful when user taps outside.
  void close() {
    if (_isOpen) {
      _controller.reverse().then((_) {
        if (mounted) setState(() => _isOpen = false);
      });
    }
  }

  bool get isOpen => _isOpen;

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) return const SizedBox.shrink();

    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Panel surface colors adapt to current theme
    final panelBg = isDarkMode
        ? const Color(0xFF1A2B20)
        : AppColors.surfaceCard;
    final dividerColor = isDarkMode
        ? const Color(0xFF2A3D2F)
        : AppColors.divider;
    final textPrimary = isDarkMode
        ? const Color(0xFFE8F5ED)
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? const Color(0xFF8FAF98)
        : AppColors.textSecondary;

    return FadeTransition(
      opacity: _opacity,
      child: SizeTransition(
        sizeFactor: _heightFactor,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.forestCanopy.withValues(alpha: 0.12),
                offset: const Offset(0, 6),
                blurRadius: 20,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.08),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
            border: Border.all(
              color: isDarkMode
                  ? AppColors.forestSage.withValues(alpha: 0.2)
                  : AppColors.divider.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Profile Row ─────────────────────────────────────────────
              _PanelTile(
                onTap: () {
                  close();
                  Navigator.pushNamed(context, AppRouter.profile);
                },
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.saffron, Color(0xFFFF9E3D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.forestSage.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user?.name.isNotEmpty == true
                              ? user!.name[0].toUpperCase()
                              : 'V',
                          style: AppTypography.title.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Name + role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name.isNotEmpty == true
                                ? user!.name
                                : 'VanMitra User',
                            style: AppTypography.subtitle.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.role.name.toUpperCase() ?? 'CITIZEN',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                              fontSize: 10.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: dividerColor),

              // ── Theme Toggle Row ────────────────────────────────────────
              _PanelTile(
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.forestCanopy.withValues(alpha: 0.5)
                            : AppColors.saffron.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? AppColors.forestMist : AppColors.saffron,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Label
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: AppTypography.subtitle.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDark ? 'Dark mode is on' : 'Light mode is on',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Animated pill toggle
                    _ThemePillSwitch(isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Panel Tile ───────────────────────────────────────────────────────────────

class _PanelTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PanelTile({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        child: child,
      ),
    );
  }
}

// ─── Animated Light/Dark Pill Switch ─────────────────────────────────────────

/// A custom sliding pill toggle — like an iOS Switch but themed to VanMitra's
/// forest palette.
class _ThemePillSwitch extends StatelessWidget {
  final bool isDark;
  const _ThemePillSwitch({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: 52,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.forestSage, const Color(0xFF143526)]
              : [const Color(0xFFFFD580), AppColors.saffron],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.forestSage.withValues(alpha: 0.3)
                : AppColors.saffron.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sliding knob
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            left: isDark ? 26 : 2,
            top: 2,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    key: ValueKey(isDark),
                    size: 13,
                    color: isDark
                        ? AppColors.forestCanopy
                        : AppColors.saffron,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
