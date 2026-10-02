import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/localization_service.dart';
import 'sync_status_chip.dart';

/// Universal AppHeader with signature Forest Canopy brand background,
/// village identity, sync diagnostics, language switcher, and optional TTS read-aloud affordance.
///
/// Phase 2 additions:
/// - [onSettingsTap] callback: connected to the sliding SettingsPanel in PortalFrameScaffold
/// - Left leading area now contains a settings/menu icon that opens the panel
/// - Profile avatar removed from header (it lives inside the SettingsPanel now)
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBackTap;
  final VoidCallback? onTtsTap;
  final List<Widget>? actions;
  final bool showSyncChip;
  final bool showProfile;

  /// Called when the settings/menu button is tapped — parent wires this
  /// to [SettingsPanelState.toggle()].
  final VoidCallback? onSettingsTap;

  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = false,
    this.onBackTap,
    this.onTtsTap,
    this.actions,
    this.showSyncChip = true,
    this.showProfile = true,
    this.onSettingsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final lang = locale.languageCode;
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    final canPop = Navigator.of(context).canPop();
    final effectiveBack = showBack || (canPop && onBackTap != null);

    return Container(
      height: preferredSize.height + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: AppSpacing.sm,
        right: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.forestCanopy,
        boxShadow: [
          BoxShadow(
            color: Color(0x330A1F16),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Leading: Back button OR animated settings/menu icon ────────────
          if (effectiveBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textOnBrand, size: 20),
              onPressed: onBackTap ?? () => Navigator.of(context).pop(),
            )
          else
            _SettingsMenuButton(onTap: onSettingsTap),

          const SizedBox(width: AppSpacing.xs),

          // ── Title & Subtitle ───────────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? context.tr('app_title'),
                  style: AppTypography.title.copyWith(
                    color: AppColors.textOnBrand,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle ?? user?.villageId ?? 'Ozhar Gram Panchayat',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.forestMist,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Optional TTS Read-Aloud ────────────────────────────────────────
          if (onTtsTap != null)
            IconButton(
              tooltip: 'Read Aloud (TTS)',
              icon: const Icon(Icons.volume_up_rounded,
                  color: AppColors.saffron, size: 22),
              onPressed: onTtsTap,
            ),

          // ── Offline / Cloud Sync Chip ──────────────────────────────────────
          if (showSyncChip) ...[
            const SyncStatusChip(showLabel: false, isLight: true),
            const SizedBox(width: AppSpacing.sm),
          ],

          // ── Language Switcher Dropdown ─────────────────────────────────────
          _LanguageMenuButton(currentLang: lang),

          // ── Profile Avatar (kept for non-dashboard screens without panel) ──
          if (showProfile && onSettingsTap == null)
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRouter.profile),
              child: Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.forestSage,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : 'V',
                    style: AppTypography.title.copyWith(
                      color: AppColors.textOnBrand,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

// ─── Settings / Menu trigger button ──────────────────────────────────────────

/// Animated settings button in the header's leading area.
/// Shows a subtle rotation animation on press to signal interactivity.
class _SettingsMenuButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _SettingsMenuButton({this.onTap});

  @override
  State<_SettingsMenuButton> createState() => _SettingsMenuButtonState();
}

class _SettingsMenuButtonState extends State<_SettingsMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotController;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rotation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _rotController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _rotController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_rotController.isCompleted) {
      _rotController.reverse();
    } else {
      _rotController.forward();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: AnimatedBuilder(
          animation: _rotController,
          builder: (_, __) => Transform.rotate(
            angle: _rotation.value * 3.14159 * 2,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.forestSage,
                border: Border.all(color: AppColors.saffron, width: 2),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.textOnBrand,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Language Switcher ────────────────────────────────────────────────────────

class _LanguageMenuButton extends ConsumerWidget {
  final String currentLang;
  const _LanguageMenuButton({required this.currentLang});

  static const _langs = {
    'mr': 'मराठी',
    'en': 'EN',
    'hi': 'हिं',
    'kn': 'ಕ',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      initialValue: currentLang,
      onSelected: (lang) => ref.read(localeProvider.notifier).setLocale(lang),
      itemBuilder: (ctx) => _langs.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _langs[currentLang] ?? currentLang.toUpperCase(),
              style: AppTypography.caption.copyWith(
                color: AppColors.textOnBrand,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                color: AppColors.textOnBrand, size: 14),
          ],
        ),
      ),
    );
  }
}
