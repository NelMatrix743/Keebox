import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onSignIn,
    required this.onGetStarted,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    const labelStyle = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          minimum: const EdgeInsets.only(bottom: 26),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(
                      379.0,
                      constraints.maxWidth * 379 / 402,
                    );
                    return Align(
                      alignment: const Alignment(0, -0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Image.asset(
                          AppAssets.onboarding,
                          width: width,
                          height: width * 505 / 379,
                          fit: BoxFit.contain,
                          semanticLabel:
                              'Keebox. Your thoughts and access secured. '
                              'Secure notes, credentials, private by design, '
                              'and data backup.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: onSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 2,
                        ),
                        shape: shape,
                        textStyle: labelStyle,
                      ),
                      child: const Text('Sign In'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onGetStarted,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.background,
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: shape,
                        textStyle: labelStyle,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Get Started',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            AppAssets.getStarted,
                            width: 24,
                            height: 24,
                            excludeFromSemantics: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
