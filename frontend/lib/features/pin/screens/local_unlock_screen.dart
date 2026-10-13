import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/shared/screens/lock_screen.dart';
import 'package:keebox/features/pin/state/local_unlock_controller.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class LocalUnlockScreen extends ConsumerStatefulWidget {
  const LocalUnlockScreen({
    required this.onUnlocked,
    required this.onLoginRequired,
    this.onResetPin,
    super.key,
  });

  final VoidCallback onUnlocked;
  final VoidCallback onLoginRequired;
  final VoidCallback? onResetPin;

  @override
  ConsumerState<LocalUnlockScreen> createState() => _LocalUnlockScreenState();
}

class _LocalUnlockScreenState extends ConsumerState<LocalUnlockScreen> {
  final _screenIdentity = Object();

  @override
  Widget build(BuildContext context) {
    final provider = localUnlockControllerProvider(_screenIdentity);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.entryRevision != previous?.entryRevision) {
        AppSnackBar.show(
          context,
          message: next.errorMessage!,
          type: AppSnackBarType.error,
        );
      }
      if (next.requiresLogin && previous?.requiresLogin != true) {
        widget.onLoginRequired();
      } else if (next.isUnlocked && previous?.isUnlocked != true) {
        AppSnackBar.dismiss(context);
        widget.onUnlocked();
      }
    });
    return LockScreen(
      isSubmitting: state.isSubmitting,
      entryRevision: state.entryRevision,
      onPinEntered: (pin) {
        AppSnackBar.dismiss(context);
        unawaited(ref.read(provider.notifier).submit(pin));
      },
      onResetPin: widget.onResetPin,
    );
  }
}
