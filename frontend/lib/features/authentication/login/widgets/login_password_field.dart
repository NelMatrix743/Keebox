import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/login/widgets/login_field_decoration.dart';

class LoginPasswordField extends StatefulWidget {
  const LoginPasswordField({
    required this.controller,
    required this.onSubmitted,
    super.key,
  });
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  State<LoginPasswordField> createState() => _LoginPasswordFieldState();
}

class _LoginPasswordFieldState extends State<LoginPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Password', style: loginFieldLabelStyle),
      SizedBox(height: 8.h),
      TextFormField(
        controller: widget.controller,
        style: loginFieldTextStyle,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onFieldSubmitted: (_) => widget.onSubmitted(),
        decoration: loginFieldDecoration(
          hint: 'Your password',
          icon: AppAssets.password,
          suffix: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: _obscure
                ? Image.asset(
                    AppAssets.passwordHidden,
                    width: 24.r,
                    height: 24.r,
                    excludeFromSemantics: true,
                  )
                : Icon(
                    Icons.visibility_outlined,
                    color: AppColors.mutedText,
                    size: 24.r,
                  ),
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Enter your password' : null,
      ),
    ],
  );
}
