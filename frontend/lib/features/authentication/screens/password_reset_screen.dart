import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/widgets/password_reset_header.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_password_field.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({
    required this.scope,
    required this.onCompleted,
    required this.onRestart,
    required this.onLoginRequired,
    super.key,
  });
  final RecoveryScope scope;
  final ValueChanged<RecoveryScope> onCompleted;
  final VoidCallback onRestart;
  final VoidCallback onLoginRequired;

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final Timer _timer;
  bool _passwordEdited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkDeadline(),
    );
  }

  void _checkDeadline() {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    ref
        .read(recoveryControllerProvider(widget.scope).notifier)
        .checkDeadlines();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDeadline();
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = recoveryControllerProvider(widget.scope);
    final state = ref.read(provider);
    if (state.stage != RecoveryStage.credential ||
        state.isSubmitting ||
        widget.scope.type != RecoveryType.password ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppSnackBar.dismiss(context);
    unawaited(ref.read(provider.notifier).completePassword(_password.text));
  }

  String? _passwordError(RecoveryState state) {
    if (_passwordEdited) return null;
    if (state.errorCode == 'invalid_password') return state.errorMessage;
    final details = state.errorDetails;
    if (state.errorCode != 'validation_error' || details is! List) return null;
    final messages = <String>[];
    for (final detail in details) {
      if (detail is! Map) continue;
      final location = detail['location'];
      final message = detail['message'];
      if (location is List &&
          location.isNotEmpty &&
          location.last == 'new_password' &&
          message is String &&
          message.trim().isNotEmpty) {
        messages.add(message);
      }
    }
    return messages.isEmpty ? null : messages.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final provider = recoveryControllerProvider(widget.scope);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.feedbackRevision != previous?.feedbackRevision) {
        _passwordEdited = false;
        if (ModalRoute.of(context)?.isCurrent != false) {
          AppSnackBar.show(
            context,
            message: next.errorMessage!,
            type: AppSnackBarType.error,
          );
        }
      }
      if (next.stage == RecoveryStage.completed &&
          previous?.stage != RecoveryStage.completed) {
        _password.clear();
        _confirmation.clear();
        widget.onCompleted(widget.scope);
      }
    });
    final active =
        state.stage == RecoveryStage.credential &&
        widget.scope.type == RecoveryType.password;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && ref.read(provider).stage != RecoveryStage.completed) {
          ref.read(provider.notifier).restart();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(26.w, 137.h, 26.w, 24.h),
            child: Column(
              children: [
                const PasswordResetHeader(),
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
                          enabled: active && !state.isSubmitting,
                          errorText: _passwordError(state),
                          onChanged: (_) =>
                              setState(() => _passwordEdited = true),
                          validator: (value) => value == null || value.isEmpty
                              ? AppTexts.recoveryPasswordRequired
                              : null,
                        ),
                        SizedBox(height: 12.h),
                        RecoveryPasswordField(
                          controller: _confirmation,
                          hint: AppTexts.confirmPasswordHint,
                          enabled: active && !state.isSubmitting,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _submit,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppTexts.confirmPasswordRequired;
                            }
                            return value != _password.text
                                ? AppTexts.passwordsDoNotMatch
                                : null;
                          },
                        ),
                        SizedBox(height: 19.h),
                        if (state.errorMessage != null &&
                            (!active || _passwordError(state) == null))
                          Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: Text(
                              state.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 14.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        RecoveryContinueButton(
                          onPressed: active && !state.isSubmitting
                              ? _submit
                              : null,
                          isLoading: state.isSubmitting,
                          loadingLabel: AppTexts.resettingPassword,
                        ),
                        if (state.stage == RecoveryStage.restartRequired ||
                            state.stage == RecoveryStage.completionUncertain)
                          TextButton(
                            onPressed: () {
                              ref.read(provider.notifier).restart();
                              widget.onRestart();
                            },
                            child: const Text(AppTexts.restartRecovery),
                          ),
                        if (state.stage == RecoveryStage.completionUncertain)
                          TextButton(
                            onPressed: widget.onLoginRequired,
                            child: const Text(AppTexts.backToLogin),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
