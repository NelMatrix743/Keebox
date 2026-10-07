import 'package:flutter/material.dart';

import 'package:keebox/network/api_exception.dart';

void showAuthenticationError(BuildContext context, Object error) {
  final message = error is APIException
      ? error.message
      : 'Unable to complete authentication. Please try again.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.red,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
}
