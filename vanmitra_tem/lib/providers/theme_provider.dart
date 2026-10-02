import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the app-wide ThemeMode (light / dark).
/// Exposed via [themeModeProvider] — watch it in MaterialApp for reactive switching.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light);

  void setLight() => state = ThemeMode.light;
  void setDark() => state = ThemeMode.dark;
  void toggle() =>
      state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
