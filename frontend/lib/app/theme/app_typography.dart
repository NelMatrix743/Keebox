import 'package:flutter/material.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

abstract final class AppTypography {
  static final TextTheme textTheme = _buildTextTheme();

  static TextTheme _buildTextTheme() {
    final base = ThemeData.light(useMaterial3: true).textTheme.apply(
      fontFamily: AppFonts.inter,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );
    return base.copyWith(
      displayLarge: base.displayLarge!.copyWith(fontFamily: AppFonts.poppins),
      displayMedium: base.displayMedium!.copyWith(fontFamily: AppFonts.poppins),
      displaySmall: base.displaySmall!.copyWith(fontFamily: AppFonts.poppins),
      headlineLarge: base.headlineLarge!.copyWith(fontFamily: AppFonts.poppins),
      headlineMedium: base.headlineMedium!.copyWith(fontFamily: AppFonts.poppins),
      headlineSmall: base.headlineSmall!.copyWith(fontFamily: AppFonts.poppins),
      titleLarge: base.titleLarge!.copyWith(fontFamily: AppFonts.poppins),
      titleMedium: base.titleMedium!.copyWith(fontFamily: AppFonts.poppins),
      titleSmall: base.titleSmall!.copyWith(fontFamily: AppFonts.poppins),
    );
  }
}
