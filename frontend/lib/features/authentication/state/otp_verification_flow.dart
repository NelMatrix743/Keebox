import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';

sealed class OtpVerificationFlow {
  const OtpVerificationFlow();
  const factory OtpVerificationFlow.recovery(RecoveryScope scope) =
      _RecoveryOtpFlow;
  const factory OtpVerificationFlow.registration(Object scope) =
      _RegistrationOtpFlow;
  Object get scope;

  @override
  bool operator ==(Object other) =>
      other is OtpVerificationFlow &&
      other.runtimeType == runtimeType &&
      other.scope == scope;
  @override
  int get hashCode => Object.hash(runtimeType, scope);
}

class _RecoveryOtpFlow extends OtpVerificationFlow {
  const _RecoveryOtpFlow(this.scope);
  @override
  final RecoveryScope scope;
}

class _RegistrationOtpFlow extends OtpVerificationFlow {
  const _RegistrationOtpFlow(this.scope);
  @override
  final Object scope;
}

/// Presentation state and actions; lifecycle rules stay in each flow controller.
class OtpVerificationBinding {
  const OtpVerificationBinding({
    required this.active,
    required this.verified,
    required this.isSubmitting,
    required this.isVerifying,
    required this.isResending,
    required this.inputKey,
    required this.resendAvailableAt,
    required this.errorMessage,
    required this.feedbackRevision,
    required this.now,
    required this.canVerify,
    required this.canResend,
    required this.checkDeadlines,
    required this.restart,
    required this.verify,
    required this.resend,
  });
  final bool active;
  final bool verified;
  final bool isSubmitting;
  final bool isVerifying;
  final bool isResending;
  final Object? inputKey;
  final DateTime? resendAvailableAt;
  final String? errorMessage;
  final int feedbackRevision;
  final DateTime Function() now;
  final bool Function() canVerify;
  final bool Function() canResend;
  final void Function() checkDeadlines;
  final void Function() restart;
  final Future<void> Function(String) verify;
  final Future<void> Function() resend;
}

final otpVerificationProvider = Provider.autoDispose
    .family<OtpVerificationBinding, OtpVerificationFlow>((ref, flow) {
      switch (flow) {
        case _RecoveryOtpFlow(:final scope):
          final state = ref.watch(recoveryControllerProvider(scope));
          final controller = ref.read(
            recoveryControllerProvider(scope).notifier,
          );
          return OtpVerificationBinding(
            active: state.stage == RecoveryStage.otp,
            verified: state.stage == RecoveryStage.credential,
            isSubmitting: state.isSubmitting,
            isVerifying: state.operation == RecoveryOperation.verify,
            isResending: state.operation == RecoveryOperation.resend,
            inputKey: state.challenge,
            resendAvailableAt: state.challenge?.resendAvailableAt,
            errorMessage: state.errorMessage,
            feedbackRevision: state.feedbackRevision,
            now: ref.read(recoveryClockProvider),
            canVerify: () =>
                state.stage == RecoveryStage.otp &&
                !state.isSubmitting &&
                state.challenge!.otpExpiresAt.isAfter(
                  ref.read(recoveryClockProvider)(),
                ),
            canResend: () => controller.canResend,
            checkDeadlines: controller.checkDeadlines,
            restart: controller.restart,
            verify: controller.verifyOtp,
            resend: controller.resendOtp,
          );
        case _RegistrationOtpFlow(:final scope):
          final state = ref.watch(registrationControllerProvider(scope));
          final controller = ref.read(
            registrationControllerProvider(scope).notifier,
          );
          return OtpVerificationBinding(
            active: state.stage == RegistrationStage.otp,
            verified: state.stage == RegistrationStage.pin,
            isSubmitting: state.isSubmitting,
            isVerifying: state.operation == RegistrationOperation.verify,
            isResending: state.operation == RegistrationOperation.resend,
            inputKey: state.challenge,
            resendAvailableAt: state.challenge?.resendAvailableAt,
            errorMessage: state.errorMessage,
            feedbackRevision: state.feedbackRevision,
            now: ref.read(registrationClockProvider),
            canVerify: () => controller.canVerify,
            canResend: () => controller.canResend,
            checkDeadlines: controller.checkDeadlines,
            restart: controller.restart,
            verify: controller.verifyOtp,
            resend: controller.resendOtp,
          );
      }
    });
