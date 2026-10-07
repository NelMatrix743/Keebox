import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_pin_request.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/widgets/authentication_error_snackbar.dart';

class PinVerificationScreen extends ConsumerStatefulWidget {
  const PinVerificationScreen({super.key});

  @override
  ConsumerState<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState extends ConsumerState<PinVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _cancelToken = CancelToken();
  bool _isLoading = false;

  @override
  void dispose() {
    _cancelToken.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }
    final current = ref.read(authenticationControllerProvider).asData?.value;
    if (current is! AwaitingPin) {
      return;
    }
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await ref
          .read(authenticationApiProvider)
          .verifyPin(
            LoginPinRequest(
              loginChallengeId: current.challenge.loginChallengeId,
              pin: _pin.text,
            ),
            cancelToken: _cancelToken,
          );
      if (mounted) {
        await ref
            .read(authenticationControllerProvider.notifier)
            .completeAuthentication(result);
      }
    } catch (error) {
      if (mounted) {
        showAuthenticationError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restartLogin() async {
    if (!_isLoading) {
      await ref.read(authenticationControllerProvider.notifier).clearSession();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        _restartLogin();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Verify your PIN'),
        leading: BackButton(onPressed: _isLoading ? null : _restartLogin),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Enter your lock PIN to finish signing in.'),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pin,
                  enabled: !_isLoading,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Lock PIN'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your lock PIN'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify PIN'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _restartLogin,
                  child: const Text('Sign in again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
