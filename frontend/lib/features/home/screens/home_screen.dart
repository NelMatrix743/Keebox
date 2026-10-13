import 'package:flutter/material.dart';

import 'package:keebox/app/app_texts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(AppTexts.home)),
    body: const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(AppTexts.homePlaceholder, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}
