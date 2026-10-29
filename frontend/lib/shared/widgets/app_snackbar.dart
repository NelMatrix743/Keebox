import 'package:flutter/material.dart';
import 'package:keebox/assets/app_assets.dart';

enum AppSnackBarType { success, info, warning, error }

class AppSnackBar extends SnackBar {
  AppSnackBar({
    required String message,
    required AppSnackBarType type,
    super.key,
  }) : super(
         content: Row(
           children: [
             Image.asset(
               switch (type) {
                 AppSnackBarType.success => AppAssets.snackbarSuccess,
                 AppSnackBarType.info => AppAssets.snackbarInfo,
                 AppSnackBarType.warning => AppAssets.snackbarWarning,
                 AppSnackBarType.error => AppAssets.snackbarError,
               },
               width: 24,
               height: 24,
               color: Colors.white,
               excludeFromSemantics: true,
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Text(
                 message,
                 style: const TextStyle(color: Colors.white),
               ),
             ),
           ],
         ),
         backgroundColor: switch (type) {
           AppSnackBarType.success => Colors.green,
           AppSnackBarType.info => Colors.blue,
           AppSnackBarType.warning => const Color(0xFFFAD83B),
           AppSnackBarType.error => Colors.red,
         },
         behavior: SnackBarBehavior.floating,
         margin: const EdgeInsets.all(12),
         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
       );

  static void show(
    BuildContext context, {
    required String message,
    required AppSnackBarType type,
  }) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(AppSnackBar(message: message, type: type));
  }

  static void dismiss(BuildContext context) =>
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
}
