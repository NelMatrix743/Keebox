import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/widgets/login_field_decoration.dart';

class LoginEmailField extends StatelessWidget {
  const LoginEmailField({required this.controller, super.key});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Email address', style: loginFieldLabelStyle),
      SizedBox(height: 8.h),
      TextFormField(
        controller: controller,
        style: loginFieldTextStyle,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        autocorrect: false,
        decoration: loginFieldDecoration(
          hint: 'Your email address',
          icon: AppAssets.email,
        ),
        validator: (value) {
          final email = value?.trim() ?? '';
          if (email.isEmpty) {
            return 'Enter your email address';
          }
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    ],
  );
}
