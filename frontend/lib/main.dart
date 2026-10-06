import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/bootstrap.dart';
import 'package:keebox/app/router/app_router.dart';
import 'package:keebox/app/theme/app_theme.dart';

Future<void> main() async {
  await bootstrap(const KeeboxApp());
}

class KeeboxApp extends ConsumerWidget {
  const KeeboxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppTexts.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemUiOverlayStyle,
        child: child!,
      ),
    );
  }
}
