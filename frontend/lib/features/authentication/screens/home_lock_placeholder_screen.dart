import 'package:flutter/material.dart';

import 'package:keebox/app/app_texts.dart';

class HomeLockPlaceholderScreen extends StatelessWidget {
  const HomeLockPlaceholderScreen({required this.onBackToLogin, super.key});

  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(AppTexts.homeLockTitle)),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                AppTexts.homeLockPlaceholder,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onBackToLogin,
                child: const Text(AppTexts.backToLogin),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
