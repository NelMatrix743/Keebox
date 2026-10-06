import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/app/theme/app_typography.dart';

abstract final class AppTheme {
  static const systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.background,
      surface: AppColors.background,
      onSurface: AppColors.text,
      outline: AppColors.border,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppFonts.inter,
    textTheme: AppTypography.textTheme,
    dividerColor: AppColors.border,
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.brand, width: 2),
      ),
    ),
  );
}
