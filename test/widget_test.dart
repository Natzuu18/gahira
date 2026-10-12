import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gahira/presentation/shared_widgets/appColor.dart';

void main() {
  test('light theme uses readable gold accents and warm mineral surfaces', () {
    final theme = buildAppTheme(Brightness.light);

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, kGoldDark);
    expect(theme.scaffoldBackgroundColor, kWhite);
    expect(theme.cardTheme.elevation, 0);
  });

  test('dark theme uses gold accents on charcoal surfaces', () {
    final theme = buildAppTheme(Brightness.dark);

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, kBlack);
    expect(theme.colorScheme.surface, kBlackSoft);
    expect(theme.colorScheme.primary, const Color(0xFFD3B66F));
    expect(theme.colorScheme.onSurface, isNot(theme.colorScheme.surface));
  });
}
