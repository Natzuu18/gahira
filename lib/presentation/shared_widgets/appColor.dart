import 'package:flutter/material.dart';

// Gahira Ball Mill Management System - shared theme.
// Import this wherever colors/theme are needed instead of
// redefining them per file.

const Color kGold = Color(0xFFD4AF37);
const Color kGoldDark = Color(0xFFB8912A);

// Dark mode surfaces
const Color kBlack = Color(0xFF0D0D0D);
const Color kBlackSoft = Color(0xFF1A1A1A);

// Light mode surfaces
const Color kWhite = Color(0xFFFAF9F6);
const Color kWhiteSoft = Color(0xFFF1ECDD);

/// Global light/dark switch. Wrap MaterialApp in a ValueListenableBuilder
/// listening to this so every page rebuilds when the mode changes.
final ValueNotifier<ThemeMode> themeModeNotifier =
ValueNotifier<ThemeMode>(ThemeMode.dark);

ThemeData buildAppTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: isDark ? kBlack : kWhite,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGold,
      brightness: brightness,
      primary: kGold,
      surface: isDark ? kBlackSoft : kWhiteSoft,
    ),
  );
}

/// Convenience helpers so widgets don't need to repeat
/// `Theme.of(context).colorScheme...` everywhere.
extension AppThemeX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get textColor => isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get mutedTextColor => textColor.withOpacity(0.55);
}