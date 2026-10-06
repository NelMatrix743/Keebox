import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';

void main() {
  test('light theme applies the brand, background, text, and border colors', () {
    final theme = AppTheme.light;
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.brand);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.background);
    expect(theme.colorScheme.onSurface, AppColors.text);
    expect(theme.colorScheme.outline, AppColors.border);
    final border = theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.color, AppColors.border);
    final focusedBorder =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, AppColors.brand);
  });

  test('headings use Poppins and body text and labels use Inter', () {
    final textTheme = AppTheme.light.textTheme;
    for (final style in [
      textTheme.displayLarge, textTheme.displayMedium, textTheme.displaySmall,
      textTheme.headlineLarge, textTheme.headlineMedium, textTheme.headlineSmall,
      textTheme.titleLarge, textTheme.titleMedium, textTheme.titleSmall,
    ]) {
      expect(style!.fontFamily, 'Poppins');
      expect(style.color, AppColors.text);
    }
    for (final style in [
      textTheme.bodyLarge, textTheme.bodyMedium, textTheme.bodySmall,
      textTheme.labelLarge, textTheme.labelMedium, textTheme.labelSmall,
    ]) {
      expect(style!.fontFamily, 'Inter');
      expect(style.color, AppColors.text);
    }
  });
}
