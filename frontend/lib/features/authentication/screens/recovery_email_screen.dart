import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_email_field.dart';
import 'package:keebox/features/authentication/widgets/recovery_email_header.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RecoveryEmailScreen extends ConsumerStatefulWidget {
  const RecoveryEmailScreen({
    required this.type,
    required this.onStarted,
    super.key,
  });
  final RecoveryType type;
  final ValueChanged<RecoveryScope> onStarted;

  @override
  ConsumerState<RecoveryEmailScreen> createState() =>
      _RecoveryEmailScreenState();
}

class _RecoveryEmailScreenState extends ConsumerState<RecoveryEmailScreen> {
  final _identity = Object();
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  RecoveryScope get _scope => (identity: _identity, type: widget.type);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final provider = recoveryControllerProvider(_scope);
    if (ref.read(provider).isSubmitting || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppSnackBar.dismiss(context);
    final controller = ref.read(provider.notifier);
    controller.restart();
    unawaited(controller.start(_email.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = recoveryControllerProvider(_scope);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.feedbackRevision != previous?.feedbackRevision &&
          ModalRoute.of(context)?.isCurrent != false) {
        AppSnackBar.show(
          context,
          message: next.errorMessage!,
          type: AppSnackBarType.error,
        );
      }
      if (next.stage == RecoveryStage.otp &&
          previous?.stage != RecoveryStage.otp) {
        widget.onStarted(_scope);
      }
    });
    return Scaffold(
      appBar: const RecoveryAppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 24.h),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: const RecoveryEmailHeader(),
              ),
              SizedBox(height: 32.h),
              Center(
                child: SizedBox(
                  width: 349.w,
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RecoveryEmailField(
                            controller: _email,
                            onSubmitted: _submit,
                            enabled: !state.isSubmitting,
                          ),
                          SizedBox(height: 14.h),
                          RecoveryContinueButton(
                            onPressed: _submit,
                            isLoading: state.isSubmitting,
                          ),
                        ],
                      ),
                    ),
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
