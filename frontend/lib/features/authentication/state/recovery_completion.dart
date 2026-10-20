import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';

final recoveryCompletionProvider = FutureProvider.autoDispose
    .family<void, RecoveryScope>((ref, scope) async {
      final recovery = ref.watch(recoveryControllerProvider(scope));
      if (recovery.stage != RecoveryStage.completed ||
          recovery.completed == null ||
          recovery.completed!.resetId != recovery.resetId) {
        throw StateError('Recovery must complete before clearing a session.');
      }
      // The backend has already revoked its sessions. Clear only the local session;
      // cached user data, KBKey and the local verifier remain for the next login.
      await ref.read(authenticationControllerProvider.notifier).clearSession();
    });
