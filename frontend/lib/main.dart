import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/bootstrap.dart';
import 'package:keebox/app/router/app_router.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';

Future<void> main() async {
  await bootstrap(const KeeboxApp());
}

class KeeboxApp extends ConsumerWidget {
  const KeeboxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authenticationControllerProvider);
    return ScreenUtilInit(
      designSize: const Size(402, 874),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp.router(
        title: AppTexts.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        routerConfig: ref.watch(appRouterProvider),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemUiOverlayStyle,
          child: child!,
        ),
      ),
    );
  }
}
