import 'package:flutter/material.dart';

/// Unified VanMitra-AI Design Tokens
/// Organizes colors by functional role, establishing Forest Green (forestCanopy)
/// as the brand primary paired with Saffron accents and high-contrast surfaces.
class AppColors {
  AppColors._();

  // ── 1. Brand Tokens ────────────────────────────────────────────────────────
  /// Brand primary: Header, bottom nav base, primary surfaces — dominant app identity
  static const Color forestCanopy = Color(0xFF1B4332);
  
  /// Brand mid: Gradients (hero cards), secondary buttons, active states
  static const Color forestSage = Color(0xFF2D6A4F);
  
  /// Brand tint: Light background tints, badge fills, onboarding accents
  static const Color forestMist = Color(0xFF95D5B2);
  static const Color forestLight = Color(0xFF95D5B2);
  static const Color forestDeep = Color(0xFF0F241A);
  static const Color forestDarkSurface = Color(0xFF1A2B20);

  /// Brand accent: High-energy call-to-actions, active tab indicator, ticker bar
  static const Color saffron = Color(0xFFFF7A00);

  /// Institutional accent (demoted): Legal Rights Hub, official document stamps
  static const Color govtBlue = Color(0xFF0B3D91);

  // ── 2. Semantic & Status Tokens ─────────────────────────────────────────────
  /// Approved status, valid quorum met (warmer & brighter than forestCanopy)
  static const Color successGreen = Color(0xFF2E7D32);
  
  /// Pending verification, partial evidence, borderline quorum warnings
  static const Color warningAmber = Color(0xFFF2A900);
  
  /// Rejected claims, severe satellite alerts, hash chain tampering detected
  static const Color alertRed = Color(0xFFD32F2F);

  // ── 3. Demographic & Biometrics ─────────────────────────────────────────────
  static const Color womenPurple = Color(0xFF7B1FA2);    // Rule 4 Women quorum tracking (33%+)
  static const Color stCyan = Color(0xFF00838F);         // Scheduled Tribe representation
  static const Color pvtgOrange = Color(0xFFE65100);     // PVTG representation flags
  static const Color faceDeepPurple = Color(0xFF512DA8); // Biometric facial liveness stamp
  static const Color gpsBlue = Color(0xFF1976D2);        // Geofence verified location badge

  // ── 4. Light-Mode Surfaces & Neutral Hierarchy ────────────────────────────
  /// Screen background — faint green-gray providing rich visual depth behind white cards
  static const Color surfaceBase = Color(0xFFF4F7F5);
  
  /// Standard card / sheet surface — pure white for sunlight legibility
  static const Color surfaceCard = Color(0xFFFFFFFF);
  
  /// Stat tile backgrounds & input backgrounds — faint forest tint
  static const Color surfaceSunken = Color(0xFFEAF2ED);
  
  /// Borders, section splitters, gridlines
  static const Color divider = Color(0xFFDCE7E1);

  // ── 5. Light-Mode Typography Colors (High Contrast) ───────────────────────
  static const Color textPrimary = Color(0xFF0F172A);    // Near-black slate for maximum legibility
  static const Color textSecondary = Color(0xFF475569);  // Mid-slate for metadata & timestamps
  static const Color textTertiary = Color(0xFF94A3B8);   // Light slate for disabled/hints
  static const Color textOnBrand = Color(0xFFFFFFFF);    // White over Forest Canopy / Saffron

  // ── 6. Dark-Mode Surface & Text Companions ────────────────────────────────
  /// Dark scaffold background — deep forest black
  static const Color darkSurface = Color(0xFF0F1A14);
  /// Dark card / elevated surface
  static const Color darkCard = Color(0xFF1A2B20);
  /// Recessed input/stat backgrounds in dark mode
  static const Color darkSunken = Color(0xFF111E17);
  /// Subtle separators in dark mode
  static const Color darkDivider = Color(0xFF2A3D2F);
  /// Primary text in dark mode (clean off-white for crisp readability)
  static const Color darkText1 = Color(0xFFF1F5F9);
  /// Secondary text in dark mode (high-readability muted slate-grey)
  static const Color darkText2 = Color(0xFF94A3B8);
  /// Tertiary / disabled text in dark mode
  static const Color darkText3 = Color(0xFF64748B);

  // ── 7. Legacy / Compatibility Mappings ───────────────────────────────────
  static const Color primary = forestCanopy;
  static const Color primaryLight = forestSage;
  static const Color primaryDark = Color(0xFF0F241A);

  static const Color secondary = saffron;
  static const Color secondaryLight = Color(0xFFFF9E3D);
  static const Color secondaryDark = Color(0xFFCC5B00);

  static const Color accentSaffron = saffron;

  static const Color success = successGreen;
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = warningAmber;
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = alertRed;
  static const Color errorLight = Color(0xFFFFEBEE);

  static const Color surface = surfaceBase;
  static const Color card = surfaceCard;
  static const Color cardElevated = surfaceSunken;
  
  static const Color textOnPrimary = textOnBrand;
  static const Color textOnSecondary = textOnBrand;

  static const Color womenQuorum = womenPurple;
  static const Color womenQuorumLight = Color(0xFFF3E5F5);
  static const Color stRepresentation = stCyan;
  static const Color stRepresentationLight = Color(0xFFE0F7FA);
  static const Color pvtgRepresentation = pvtgOrange;
  static const Color pvtgRepresentationLight = Color(0xFFFBE9E7);

  static const Color gpsVerified = gpsBlue;
  static const Color faceVerified = faceDeepPurple;
  static const Color manualEntry = Color(0xFF607D8B);
}

// ── Theme-Adaptive Color Extension ─────────────────────────────────────────────
//
// Usage in widgets:
//   final c = context.colors;
//   Container(color: c.cardBg, child: Text('Hello', style: TextStyle(color: c.textPrimary)))
//
typedef AppColorScheme = AppThemeColors;

class AppThemeColors {
  const AppThemeColors(this._dark);
  final bool _dark;

  bool get isDark => _dark;

  // Surfaces
  Color get scaffoldBg    => _dark ? AppColors.darkSurface  : AppColors.surfaceBase;
  Color get cardBg        => _dark ? AppColors.darkCard     : AppColors.surfaceCard;
  Color get surface       => _dark ? AppColors.darkCard     : AppColors.surfaceCard;
  Color get sunkenBg      => _dark ? AppColors.darkSunken   : AppColors.surfaceSunken;
  Color get dialogBg      => _dark ? AppColors.darkCard     : AppColors.surfaceCard;
  Color get bottomSheetBg => _dark ? AppColors.darkCard     : AppColors.surfaceCard;

  // Bottom Navigation Bar
  Color get navBg         => _dark ? const Color(0xFF132219) : AppColors.surfaceCard;
  Color get navSelected   => _dark ? AppColors.saffron      : AppColors.forestCanopy;
  Color get navUnselected => _dark ? const Color(0xFF94A3B8) : AppColors.textTertiary;
  Color get navIndicator  => _dark ? AppColors.saffron      : AppColors.forestCanopy;
  Color get navBorder     => _dark ? const Color(0xFF23382B) : const Color(0x0D1B4332);

  // Borders / Dividers
  Color get divider       => _dark ? AppColors.darkDivider  : AppColors.divider;
  Color get border        => _dark ? AppColors.darkDivider  : AppColors.divider;

  // Text
  Color get textPrimary   => _dark ? AppColors.darkText1   : AppColors.textPrimary;
  Color get textSecondary => _dark ? AppColors.darkText2   : AppColors.textSecondary;
  Color get textTertiary  => _dark ? AppColors.darkText3   : AppColors.textTertiary;

  // Section headers & Brand accents
  Color get sectionTitle  => _dark ? AppColors.forestMist  : AppColors.forestCanopy;
  Color get statNumber    => _dark ? const Color(0xFF52B788) : AppColors.forestCanopy;
  Color get chipUnselectedBg => _dark ? const Color(0xFF16251D) : AppColors.surfaceCard;
  Color get chipUnselectedBorder => _dark ? AppColors.darkDivider : AppColors.divider;

  // Shimmer placeholder colors
  Color get shimmerBase   => _dark ? AppColors.darkCard    : const Color(0xFFE5EAE7);
  Color get shimmerHigh   => _dark ? AppColors.darkSunken  : const Color(0xFFF0F4F2);
}

extension AppColorsX on BuildContext {
  /// Returns theme-adaptive surface/text/divider colors for the active brightness.
  AppThemeColors get colors {
    final dark = Theme.of(this).brightness == Brightness.dark;
    return AppThemeColors(dark);
  }
}

