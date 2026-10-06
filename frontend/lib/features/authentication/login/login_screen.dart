import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/authentication/login/widgets/login_header.dart';
import 'package:keebox/features/authentication/login/widgets/login_email_field.dart';
import 'package:keebox/features/authentication/login/widgets/login_password_field.dart';
import 'package:keebox/features/authentication/login/widgets/forgot_password_link.dart';
import 'package:keebox/features/authentication/login/widgets/login_button.dart';
import 'package:keebox/features/authentication/login/widgets/registration_footer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.onLogin,
    this.onForgotPassword,
    this.onRegister,
    super.key,
  });
  final void Function(String email, String password)? onLogin;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onRegister;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      widget.onLogin?.call(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                            LoginEmailField(controller: _email),
                            SizedBox(height: 12.h),
                            LoginPasswordField(
                              controller: _password,
                              onSubmitted: _submit,
                            ),
                            SizedBox(height: 4.h),
                            ForgotPasswordLink(
                              onPressed: widget.onForgotPassword,
                            ),
                            SizedBox(height: 20.h),
                            LoginButton(onPressed: _submit),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: math.max(24, 24.h)),
                    const Spacer(),
                    RegistrationFooter(onPressed: widget.onRegister),
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
