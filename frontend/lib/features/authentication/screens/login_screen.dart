import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/state/login_controller.dart';
import 'package:keebox/features/authentication/widgets/login_header.dart';
import 'package:keebox/features/authentication/widgets/login_email_field.dart';
import 'package:keebox/features/authentication/widgets/login_password_field.dart';
import 'package:keebox/features/authentication/widgets/forgot_password_link.dart';
import 'package:keebox/features/authentication/widgets/login_button.dart';
import 'package:keebox/features/authentication/widgets/registration_footer.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    this.onLoginVerified,
    this.onForgotPassword,
    this.onRegister,
    super.key,
  });
  final ValueChanged<LoginChallenge>? onLoginVerified;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onRegister;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _screenIdentity = Object();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = loginControllerProvider(_screenIdentity);
    if (ref.read(provider).isSubmitting) return;
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      AppSnackBar.dismiss(context);
      unawaited(
        ref.read(provider.notifier).submit(_email.text, _password.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = loginControllerProvider(_screenIdentity);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        AppSnackBar.show(
          context,
          message: next.errorMessage!,
          type: AppSnackBarType.error,
        );
      }
      if (next.challenge != null && next.challenge != previous?.challenge) {
        _password.clear();
        widget.onLoginVerified?.call(next.challenge!);
      }
    });
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 26.w),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 44.h),
                      const LoginHeader(),
                      SizedBox(height: 62.h),
                      Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LoginEmailField(
                                controller: _email,
                                enabled: !state.isSubmitting,
                              ),
                              SizedBox(height: 12.h),
                              LoginPasswordField(
                                controller: _password,
                                onSubmitted: _submit,
                                enabled: !state.isSubmitting,
                              ),
                              SizedBox(height: 4.h),
                              ForgotPasswordLink(
                                onPressed: state.isSubmitting
                                    ? null
                                    : widget.onForgotPassword,
                              ),
                              SizedBox(height: 20.h),
                              LoginButton(
                                onPressed: _submit,
                                isLoading: state.isSubmitting,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: math.max(24, 24.h)),
                      const Spacer(),
                      RegistrationFooter(
                        onPressed: state.isSubmitting
                            ? null
                            : widget.onRegister,
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
