import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/theme/app_colors.dart';

void main() {
  test('app palette matches the approved brand colors', () {
    expect(AppColors.brand, const Color(0xFF8D08F7));
    expect(AppColors.background, const Color(0xFFFFFFFF));
    expect(AppColors.text, const Color(0xFF222222));
    expect(AppColors.border, const Color(0xFFDDDDE0));
  });
}
