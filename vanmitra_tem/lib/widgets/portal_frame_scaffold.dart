import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../providers/locale_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notices_provider.dart';
import '../services/localization_service.dart';
import 'notice_board_widget.dart';
import 'common/app_header.dart';
import 'common/settings_panel.dart';

/// MAHA-DBT / Forest Canopy Portal Frame — used as root scaffold for core screens.
///
/// Phase 2: Now hosts the [SettingsPanel] overlay. A settings gear button in
/// [AppHeader] toggles the sliding-down panel which contains:
///   • Profile quick-access row
///   • Light / Dark theme pill toggle
///
/// The panel is positioned absolutely over the content area so it overlays
/// without pushing the scroll view down.
class PortalFrameScaffold extends ConsumerStatefulWidget {
  final Widget body;
  final List<String> breadcrumbs;
  final bool showNoticeTicker;
  final bool? showBackButton;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;

  /// Header title; defaults to the app name.
  final String? title;

  /// Hide the breadcrumb bar (e.g. when the header title already says where you are).
  final bool showBreadcrumbs;

  const PortalFrameScaffold({
    super.key,
    required this.body,
    this.breadcrumbs = const [],
    this.showNoticeTicker = true,
    this.showBackButton,
    this.floatingActionButton,
    this.actions,
    this.bottomNavigationBar,
    this.title,
    this.showBreadcrumbs = true,
  });

  @override
  ConsumerState<PortalFrameScaffold> createState() =>
      _PortalFrameScaffoldState();
}

class _PortalFrameScaffoldState extends ConsumerState<PortalFrameScaffold> {
  final _settingsPanelKey = GlobalKey<SettingsPanelState>();
  bool _panelOpen = false;

  void _toggleSettings() {
    final nextOpen = !_panelOpen;
    setState(() => _panelOpen = nextOpen);
    if (nextOpen) {
      _settingsPanelKey.currentState?.toggle();
    } else {
      _settingsPanelKey.currentState?.close();
    }
  }

  void _closeSettings() {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      _settingsPanelKey.currentState?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final lang = locale.languageCode;
    final auth = ref.watch(authProvider);
    final notices = ref.watch(noticesProvider);
    final canPop = Navigator.of(context).canPop();
    final showBack = widget.showBackButton ?? canPop;

    final List<String> effectiveBreadcrumbs = widget.breadcrumbs.isEmpty
        ? <String>[context.tr('tab_dashboard')]
        : widget.breadcrumbs;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          // ── Base layout column ───────────────────────────────────────────
          Column(
            children: [
              // ── AppHeader with settings trigger ─────────────────────────
              AppHeader(
                showBack: showBack,
                actions: widget.actions,
                title: widget.title ?? context.tr('app_title'),
                subtitle: auth.currentUser?.villageId ??
                    context.tr('default_village_name'),
                onSettingsTap: _toggleSettings,
              ),

              // ── Notice Ticker ────────────────────────────────────────────
              if (widget.showNoticeTicker && notices.activeNotices.isNotEmpty)
                NoticeBoardWidget(
                  notices: notices.activeNotices,
                  mode: NoticeBoardMode.ticker,
                  lang: lang,
                  onDismiss: (id) =>
                      ref.read(noticesProvider.notifier).dismissNotice(id),
                ),

              // ── Breadcrumbs ──────────────────────────────────────────────
              if (widget.showBreadcrumbs && effectiveBreadcrumbs.isNotEmpty)
                _BreadcrumbBar(breadcrumbs: effectiveBreadcrumbs),

              // ── Main Content Body ────────────────────────────────────────
              Expanded(child: widget.body),

              // ── Footer ───────────────────────────────────────────────────
              const _PortalFooter(),
            ],
          ),

          // ── Transparent dismiss scrim when panel is open ─────────────────
          // IMPORTANT: This must be BELOW the SettingsPanel in the Stack so
          // taps on the panel (e.g. the theme toggle) reach the panel first
          // and do NOT bubble down to the scrim, keeping the panel open.
          if (_panelOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSettings,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          // ── Settings Panel overlay (sits just below AppHeader) ───────────
          // Must be ABOVE the scrim so its taps are not intercepted.
          Positioned(
            top: kToolbarHeight +
                MediaQuery.of(context).padding.top +
                AppSpacing.xs,
            left: 0,
            right: 0,
            // GestureDetector with opaque behaviour absorbs all taps inside
            // the panel, preventing them from reaching the dismiss scrim below.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorb — prevents scrim from firing
              child: SettingsPanel(key: _settingsPanelKey),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Breadcrumb Bar ───────────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  final List<String> breadcrumbs;
  const _BreadcrumbBar({required this.breadcrumbs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF111E17) : AppColors.surfaceSunken,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          for (int i = 0; i < breadcrumbs.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('›',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.forestMist
                          : AppColors.textSecondary,
                      fontSize: 12,
                    )),
              ),
            GestureDetector(
              onTap: i < breadcrumbs.length - 1
                  ? () {
                      final popsNeeded = breadcrumbs.length - 1 - i;
                      for (var p = 0; p < popsNeeded; p++) {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      }
                    }
                  : null,
              child: Text(
                context.tr(breadcrumbs[i]),
                style: TextStyle(
                  fontFamily: 'NotoSansDevanagari',
                  fontSize: 12,
                  color: i == breadcrumbs.length - 1
                      ? AppColors.forestSage
                      : (isDark
                          ? AppColors.forestMist
                          : AppColors.textSecondary),
                  fontWeight: i == breadcrumbs.length - 1
                      ? FontWeight.w700
                      : FontWeight.w500,
                  decoration: i < breadcrumbs.length - 1
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _PortalFooter extends StatelessWidget {
  const _PortalFooter();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      color: c.isDark ? const Color(0xFF0F1E16) : AppColors.forestCanopy,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        context.tr('footer_text'),
        style: TextStyle(
          fontFamily: 'NotoSansDevanagari',
          color: c.isDark ? AppColors.darkText2 : const Color(0xDDFFFFFF),
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}


