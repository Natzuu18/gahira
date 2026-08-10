import 'package:flutter/material.dart';

import 'appColor.dart';

// Reusable light/dark mode toggle button.
// Drop <ThemeToggleButton() into any AppBar's actions (or anywhere else)
// on any page — it reads and flips the shared themeModeNotifier, so every
// page stays in sync automatically.

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        final bool isDark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: kGold,
          ),
          onPressed: () {
            themeModeNotifier.value =
            isDark ? ThemeMode.light : ThemeMode.dark;
          },
        );
      },
    );
  }
}