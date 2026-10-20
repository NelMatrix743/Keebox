import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_fields.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_header.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_resend.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RecoveryOtpScreen extends ConsumerStatefulWidget {
  const RecoveryOtpScreen({
    required this.scope,
    required this.onVerified,
    required this.onRestart,
    super.key,
  });
  final RecoveryScope scope;
  final ValueChanged<RecoveryScope> onVerified;
  final VoidCallback onRestart;

  @override
  ConsumerState<RecoveryOtpScreen> createState() => _RecoveryOtpScreenState();
}

class _RecoveryOtpScreenState extends ConsumerState<RecoveryOtpScreen>
    with WidgetsBindingObserver {
  late final Timer _timer;
  String _code = '';
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    ref
        .read(recoveryControllerProvider(widget.scope).notifier)
        .checkDeadlines();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _submit() {
    final provider = recoveryControllerProvider(widget.scope);
    final state = ref.read(provider);
    if (_code.length != 6 ||
        state.isSubmitting ||
        state.stage != RecoveryStage.otp) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppSnackBar.dismiss(context);
    unawaited(ref.read(provider.notifier).verifyOtp(_code));
  }

  void _restart() {
    ref.read(recoveryControllerProvider(widget.scope).notifier).restart();
    widget.onRestart();
  }

  @override
  Widget build(BuildContext context) {
    final provider = recoveryControllerProvider(widget.scope);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (previous?.challenge != next.challenge) {
        _code = '';
        _edited = false;
      }
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
      if (next.stage == RecoveryStage.credential &&
          previous?.stage != RecoveryStage.credential) {
        _code = '';
        widget.onVerified(widget.scope);
      }
    });
    final active = state.stage == RecoveryStage.otp;
    final now = ref.read(recoveryClockProvider)();
    final remainingMs =
        state.challenge?.resendAvailableAt.difference(now).inMilliseconds ?? 0;
    final remaining = Duration(
      seconds: remainingMs > 0 ? (remainingMs / 1000).ceil() : 0,
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && ref.read(provider).stage != RecoveryStage.credential) {
          ref.read(provider.notifier).restart();
        }
      },
      child: Scaffold(
        appBar: const RecoveryAppBar(),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: 24.h),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: const RecoveryOtpHeader(),
                ),
                SizedBox(height: 32.h),
                Center(
                  child: SizedBox(
                    width: 320.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RecoveryOtpFields(
                          key: ValueKey(state.challenge),
                          enabled: active && !state.isSubmitting,
                          onChanged: (code) => setState(() {
                            _code = code;
                            _edited = true;
                          }),
                          onSubmitted: _submit,
                        ),
                        if (!_edited && state.errorMessage != null)
                          Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: Text(
                              state.errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        if (active)
                          RecoveryOtpResend(
                            remaining: remaining,
                            isLoading:
                                state.operation == RecoveryOperation.resend,
                            onPressed: state.isSubmitting
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    AppSnackBar.dismiss(context);
                                    unawaited(
                                      ref.read(provider.notifier).resendOtp(),
                                    );
                                  },
                          ),
                        SizedBox(height: 16.h),
                        RecoveryContinueButton(
                          onPressed:
                              active && !state.isSubmitting && _code.length == 6
                              ? _submit
                              : null,
                          isLoading:
                              state.operation == RecoveryOperation.verify,
                          loadingLabel: AppTexts.verifyingOtp,
                        ),
                        if (!active && state.stage != RecoveryStage.credential)
                          TextButton(
                            onPressed: _restart,
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
      ),
    );
  }
}
