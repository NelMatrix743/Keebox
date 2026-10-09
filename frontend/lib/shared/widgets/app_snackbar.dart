import 'package:flutter/material.dart';

enum AppSnackBarType { success, info, warning, error }

class AppSnackBar extends SnackBar {
  AppSnackBar({
    required String message,
    required AppSnackBarType type,
    super.key,
  }) : super(
         content: Text(
           message,
           style: TextStyle(
             color: type == AppSnackBarType.warning
                 ? Colors.black
                 : Colors.white,
           ),
         ),
         backgroundColor: switch (type) {
           AppSnackBarType.success => Colors.green,
           AppSnackBarType.info => Colors.blue,
           AppSnackBarType.warning => Colors.yellow,
           AppSnackBarType.error => Colors.red,
         },
         behavior: SnackBarBehavior.fixed,
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
