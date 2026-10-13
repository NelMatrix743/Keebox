import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/pin/local_pin_policy.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/state/local_unlock_state.dart';

final localUnlockControllerProvider = NotifierProvider.autoDispose
    .family<LocalUnlockController, LocalUnlockState, Object>(
      (_) => LocalUnlockController(),
    );

class LocalUnlockController extends Notifier<LocalUnlockState> {
  int _operation = 0;
  AuthenticatedLocked? _lockedSession;

  @override
  LocalUnlockState build() {
    ref.onDispose(() => _operation++);
    ref.listen(authenticationControllerProvider, (_, next) {
      if (!state.isSubmitting) return;
      final current = next.asData?.value;
      if (identical(current, _lockedSession) ||
          current is AuthenticatedUnlocked &&
              identical(current.session, _lockedSession?.session) &&
              identical(current.user, _lockedSession?.user)) {
        return;
      }
      _operation++;
      state = LocalUnlockState(
        entryRevision: state.entryRevision + 1,
        requiresLogin: current is Unauthenticated,
        errorMessage: current is Unauthenticated
            ? AppTexts.localPinLoginRequired
            : null,
      );
    });
    return const LocalUnlockState();
  }

  Future<void> submit(String pin) async {
    if (state.isSubmitting ||
        state.isUnlocked ||
        state.requiresLogin ||
        !LocalPinPolicy.isValid(pin)) {
      return;
    }
    final current = ref.read(authenticationControllerProvider).asData?.value;
    if (current is! AuthenticatedLocked) return;
    _lockedSession = current;
    final operation = ++_operation;
    bool isActive() => ref.mounted && operation == _operation;
    final revision = state.entryRevision;
    state = LocalUnlockState(isSubmitting: true, entryRevision: revision);
    try {
      final result = await ref
          .read(authenticationControllerProvider.notifier)
          .verifyLocalPin(pin, isActive: isActive);
      if (!isActive()) return;
      final authenticated = ref
          .read(authenticationControllerProvider)
          .asData
          ?.value;
      if (result.status == LocalPinStatus.matched &&
          authenticated is AuthenticatedUnlocked &&
          identical(authenticated.session, current.session) &&
          identical(authenticated.user, current.user)) {
        state = LocalUnlockState(isUnlocked: true, entryRevision: revision);
        return;
      }
      state = LocalUnlockState(
        entryRevision: revision + 1,
        requiresLogin: result.status == LocalPinStatus.requiresReauthentication,
        errorMessage: switch (result.status) {
          LocalPinStatus.incorrect => AppTexts.localPinIncorrect(
            result.remainingAttempts,
          ),
          LocalPinStatus.requiresReauthentication =>
            AppTexts.localPinLoginRequired,
          _ => AppTexts.pinVerificationFailed,
        },
      );
    } catch (_) {
      if (!isActive()) return;
      state = LocalUnlockState(
        entryRevision: revision + 1,
        errorMessage: AppTexts.pinVerificationFailed,
      );
    }
  }
}
