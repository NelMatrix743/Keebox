import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/registration_completion_state.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';

final registrationCompletionControllerProvider = NotifierProvider.autoDispose
    .family<
      RegistrationCompletionController,
      RegistrationCompletionState,
      Object
    >(RegistrationCompletionController.new);

class RegistrationCompletionController
    extends Notifier<RegistrationCompletionState> {
  RegistrationCompletionController(this.scope);
  final Object scope;

  // Retained in memory only until persistence succeeds or this flow is disposed.
  String? _acceptedPin;
  int _revision = 0;

  @override
  RegistrationCompletionState build() {
    _revision++;
    ref.onDispose(() {
      _revision++;
      _acceptedPin = null;
    });
    return const RegistrationCompletionState();
  }

  Future<bool> submit(String pin) async {
    final revision = _revision;
    final registration = ref.read(registrationControllerProvider(scope));
    if (state.isSubmitting ||
        state.isReady ||
        registration.stage != RegistrationStage.pin) {
      return false;
    }
    state = const RegistrationCompletionState(
      phase: RegistrationCompletionPhase.submitting,
    );
    await ref
        .read(registrationControllerProvider(scope).notifier)
        .complete(pin);
    if (!ref.mounted || revision != _revision) return false;
    final completed = ref.read(registrationControllerProvider(scope));
    if (completed.stage != RegistrationStage.completed ||
        completed.completed == null) {
      state = const RegistrationCompletionState();
      return false;
    }
    _acceptedPin = pin;
    return _save(completed.completed!, revision);
  }

  Future<bool> retry() async {
    if (!state.canRetry || _acceptedPin == null) return false;
    final registration = ref.read(registrationControllerProvider(scope));
    if (registration.stage != RegistrationStage.completed ||
        registration.completed == null) {
      return false;
    }
    state = const RegistrationCompletionState(
      phase: RegistrationCompletionPhase.submitting,
    );
    return _save(registration.completed!, _revision);
  }

  Future<bool> _save(AuthenticationResult result, int revision) async {
    bool active() =>
        ref.mounted &&
        revision == _revision &&
        identical(
          ref.read(registrationControllerProvider(scope)).completed,
          result,
        );
    final auth = ref.read(authenticationControllerProvider.notifier);
    try {
      await auth.completeAuthentication(
        result,
        verifiedPin: _acceptedPin!,
        isActive: active,
      );
      if (!active()) return false;
      final authenticated = ref
          .read(authenticationControllerProvider)
          .asData
          ?.value;
      if (authenticated is! Authenticated ||
          authenticated.user.id != result.user.id ||
          authenticated.session.accessToken != result.session.accessToken) {
        throw StateError('Registration session was not established.');
      }
      _acceptedPin = null;
      state = const RegistrationCompletionState(
        phase: RegistrationCompletionPhase.ready,
      );
      return true;
    } catch (_) {
      if (!active()) return false;
      try {
        await auth.clearSession();
      } catch (_) {
        // clearSession invalidates in-memory access even if storage is unavailable.
      }
      if (!active()) return false;
      state = const RegistrationCompletionState(
        phase: RegistrationCompletionPhase.saveFailed,
        errorMessage: AppTexts.registrationSessionSaveFailed,
      );
      return false;
    }
  }
}
