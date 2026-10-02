/// Barrel export file for VanMitra-AI Unified Design System & Common Components.
/// Any module can import this single file to get full access to all theme tokens and shared UI elements.
library app_components;

// Theme & Tokens
export '../../core/theme/app_colors.dart';
export '../../core/theme/app_elevation.dart';
export '../../core/theme/app_radius.dart';
export '../../core/theme/app_spacing.dart';
export '../../core/theme/app_typography.dart';

// Shared Components (Phase 1)
export 'action_list_item.dart';
export 'app_card.dart';
export 'app_header.dart';
export 'bottom_nav_bar.dart';
export 'empty_state.dart';
export 'greeting_hero.dart';
export 'notice_ticker.dart';
export 'primary_button.dart';
export 'secondary_button.dart';
export 'stat_tile.dart';
export 'status_badge.dart';
export 'sync_status_chip.dart';

// Shared Components (Phase 2 — Animation & Polish)
export 'animated_bottom_nav_bar.dart';
export 'animated_counter.dart';
export 'bouncing_card.dart';
export 'settings_panel.dart';
