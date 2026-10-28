import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/otp_verification_flow.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_fields.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_header.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_resend.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    required this.flow,
    this.onVerified,
    required this.onRestart,
    this.onBack,
    super.key,
  });
  final OtpVerificationFlow flow;
  final VoidCallback? onVerified;
  final VoidCallback onRestart;
  final VoidCallback? onBack;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
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
    ref.read(otpVerificationProvider(widget.flow)).checkDeadlines();
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
    final state = ref.read(otpVerificationProvider(widget.flow));
    if (_code.length != 6 || state.isSubmitting || !state.canVerify()) {
      return;
    }
    FocusScope.of(context).unfocus();
    AppSnackBar.dismiss(context);
    unawaited(state.verify(_code));
  }

  void _restart() {
    ref.read(otpVerificationProvider(widget.flow)).restart();
    widget.onRestart();
  }

  @override
  Widget build(BuildContext context) {
    final provider = otpVerificationProvider(widget.flow);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (previous?.inputKey != next.inputKey) {
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
      if (next.verified && previous?.verified != true) {
        _code = '';
        widget.onVerified?.call();
      }
    });
    final active = state.active;
    final now = state.now();
    final remainingMs =
        state.resendAvailableAt?.difference(now).inMilliseconds ?? 0;
    final remaining = Duration(
      seconds: remainingMs > 0 ? (remainingMs / 1000).ceil() : 0,
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !ref.read(provider).verified) {
          ref.read(provider).restart();
        }
      },
      child: Scaffold(
        appBar: RecoveryAppBar(onBack: widget.onBack),
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
                          key: ValueKey(state.inputKey),
                          enabled: active && state.canVerify(),
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
                            isLoading: state.isResending,
                            onPressed: !state.canResend()
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    AppSnackBar.dismiss(context);
                                    unawaited(ref.read(provider).resend());
                                  },
                          ),
                        SizedBox(height: 16.h),
                        RecoveryContinueButton(
                          onPressed:
                              active && state.canVerify() && _code.length == 6
                              ? _submit
                              : null,
                          isLoading: state.isVerifying,
                          loadingLabel: AppTexts.verifyingOtp,
                        ),
                        if (!active && !state.verified)
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
