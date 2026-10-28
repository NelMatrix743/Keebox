import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/models/registration_identity.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_field_errors.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_password_field.dart';
import 'package:keebox/features/authentication/widgets/registration_header.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RegistrationPasswordScreen extends ConsumerStatefulWidget {
  const RegistrationPasswordScreen({
    required this.identity,
    required this.scope,
    required this.onBack,
    super.key,
  });
  final RegistrationIdentity identity;
  final Object scope;
  final VoidCallback onBack;
  @override
  ConsumerState<RegistrationPasswordScreen> createState() =>
      _RegistrationPasswordScreenState();
}

class _RegistrationPasswordScreenState
    extends ConsumerState<RegistrationPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _edited = false;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = registrationControllerProvider(widget.scope);
    final state = ref.read(provider);
    if (state.isSubmitting ||
        state.stage != RegistrationStage.form ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppSnackBar.dismiss(context);
    unawaited(
      ref
          .read(provider.notifier)
          .start(
            RegistrationRequest(
              firstName: widget.identity.firstName,
              lastName: widget.identity.lastName,
              email: widget.identity.email,
              password: _password.text,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = registrationControllerProvider(widget.scope);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.feedbackRevision != previous?.feedbackRevision) {
        _edited = false;
        if (ModalRoute.of(context)?.isCurrent != false) {
          AppSnackBar.show(
            context,
            message: next.errorMessage!,
            type: AppSnackBarType.error,
          );
        }
      }
    });
    final active = state.stage == RegistrationStage.form && !state.isSubmitting;
    return Scaffold(
      appBar: RecoveryAppBar(onBack: widget.onBack),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(26.w, 59.h, 26.w, 24.h),
          child: Column(
            children: [
              const RegistrationHeader(
                image: AppAssets.passwordReset,
                title: AppTexts.registrationPasswordTitle,
                subtitle: AppTexts.registrationPasswordSubtitle,
                gap: 11,
                imageOffset: 5,
              ),
              SizedBox(height: 42.h),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RecoveryPasswordField(
                        controller: _password,
                        hint: AppTexts.newPasswordHint,
                        prefixGap: 0,
                        enabled: active,
                        errorText: _edited
                            ? null
                            : registrationFieldError(state, 'password'),
                        onChanged: (_) => setState(() => _edited = true),
                        validator: (value) => value == null || value.isEmpty
                            ? AppTexts.registrationPasswordRequired
                            : null,
                      ),
                      SizedBox(height: 12.h),
                      RecoveryPasswordField(
                        controller: _confirmation,
                        hint: AppTexts.confirmPasswordHint,
                        prefixGap: 0,
                        enabled: active,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _submit,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppTexts.registrationConfirmPasswordRequired;
                          }
                          return value == _password.text
                              ? null
                              : AppTexts.passwordsDoNotMatch;
                        },
                      ),
                      SizedBox(height: 19.h),
                      RecoveryContinueButton(
                        onPressed: active ? _submit : null,
                        isLoading: state.isSubmitting,
                        loadingLabel: AppTexts.registering,
                        iconGap: 4,
                      ),
                      if (state.stage == RegistrationStage.restartRequired)
                        TextButton(
                          onPressed: widget.onBack,
                          child: const Text(AppTexts.restartRecovery),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
