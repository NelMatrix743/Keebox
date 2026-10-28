import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/screens/authentication_success_screen.dart';
import 'package:keebox/features/authentication/screens/registration_pin_screen.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/models/registration_identity.dart';
import 'package:keebox/features/authentication/screens/registration_identity_screen.dart';
import 'package:keebox/features/authentication/screens/registration_password_screen.dart';
import 'package:keebox/features/authentication/screens/otp_verification_screen.dart';
import 'package:keebox/features/authentication/state/otp_verification_flow.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({
    required this.onSignIn,
    this.onRegistered,
    super.key,
  });
  final VoidCallback onSignIn;
  final VoidCallback? onRegistered;
  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _scope = Object();
  RegistrationIdentity _identity = (firstName: '', lastName: '', email: '');
  bool _password = false;
  void _back() {
    final completion = ref.read(
      registrationCompletionControllerProvider(_scope),
    );
    if (completion.isSubmitting ||
        completion.isReady ||
        ref.read(registrationControllerProvider(_scope)).stage ==
            RegistrationStage.completed) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppSnackBar.dismiss(context);
    final provider = registrationControllerProvider(_scope);
    final state = ref.read(provider);
    if (state.isSubmitting || state.stage != RegistrationStage.form) {
      ref.read(provider.notifier).restart();
    }
    setState(() => _password = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = registrationControllerProvider(_scope);
    final state = ref.watch(provider);
    final completion = ref.watch(
      registrationCompletionControllerProvider(_scope),
    );
    final pin = state.verified != null;
    final otp = state.challenge != null && !pin;
    return PopScope(
      canPop: !_password && !otp && !pin,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_password || otp || pin)) _back();
      },
      child: completion.isReady
          ? AuthenticationSuccessScreen(
              message: AppTexts.registrationCompletedMessage,
              semanticsLabel: AppTexts.registrationCompletedTitle,
              onContinue: widget.onRegistered,
            )
          : pin
          ? RegistrationPinScreen(
              scope: _scope,
              onRestart: _back,
              onSignIn: widget.onSignIn,
            )
          : otp
          ? OtpVerificationScreen(
              flow: OtpVerificationFlow.registration(_scope),
              onBack: _back,
              onRestart: _back,
            )
          : _password
          ? RegistrationPasswordScreen(
              scope: _scope,
              identity: _identity,
              onBack: _back,
            )
          : RegistrationIdentityScreen(
              identity: _identity,
              onSignIn: widget.onSignIn,
              errors: {
                for (final field in ['first_name', 'last_name', 'email'])
                  field: registrationFieldError(state, field),
              },
              onNext: (identity) {
                AppSnackBar.dismiss(context);
                ref.read(provider.notifier).restart();
                setState(() {
                  _identity = identity;
                  _password = true;
                });
              },
            ),
    );
  }
}
