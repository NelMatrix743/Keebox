import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/authentication/models/registration_identity.dart';
import 'package:keebox/features/authentication/screens/registration_identity_screen.dart';
import 'package:keebox/features/authentication/screens/registration_password_screen.dart';
import 'package:keebox/features/authentication/screens/otp_verification_screen.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/authentication/state/otp_verification_flow.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_field_errors.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({required this.onSignIn, super.key});
  final VoidCallback onSignIn;
  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _scope = Object();
  RegistrationIdentity _identity = (firstName: '', lastName: '', email: '');
  bool _password = false;
  void _back() {
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
    final pin = state.stage == RegistrationStage.pin;
    final otp = state.challenge != null && !pin;
    return PopScope(
      canPop: !_password && !otp && !pin,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_password || otp || pin)) _back();
      },
      child: pin
          ? const PinSetupScreen(mode: PinSetupMode.create, enabled: false)
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
