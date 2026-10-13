import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/authentication/state/login_pin_controller.dart';
import 'package:keebox/shared/screens/lock_screen.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class LoginPinScreen extends ConsumerStatefulWidget {
  const LoginPinScreen({
    required this.onAuthenticated,
    required this.onLoginRequired,
    this.onResetPin,
    super.key,
  });

  final VoidCallback onAuthenticated;
  final VoidCallback onLoginRequired;
  final VoidCallback? onResetPin;

  @override
  ConsumerState<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends ConsumerState<LoginPinScreen> {
  final _screenIdentity = Object();
  int _entryRevision = 0;

  @override
  Widget build(BuildContext context) {
    final provider = loginPinControllerProvider(_screenIdentity);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        setState(() => _entryRevision++);
        AppSnackBar.show(
          context,
          message: next.errorMessage!,
          type: AppSnackBarType.error,
        );
      }
      if (next.requiresLogin && previous?.requiresLogin != true) {
        widget.onLoginRequired();
      } else if (next.isAuthenticated && previous?.isAuthenticated != true) {
        AppSnackBar.dismiss(context);
        widget.onAuthenticated();
      }
    });
    return LockScreen(
      isSubmitting: state.isSubmitting,
      entryRevision: _entryRevision,
      onPinEntered: (pin) {
        AppSnackBar.dismiss(context);
        unawaited(ref.read(provider.notifier).submit(pin));
      },
      onResetPin: widget.onResetPin,
    );
  }
}
