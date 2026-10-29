import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/models/registration_identity.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/registration_header.dart';
import 'package:keebox/features/authentication/widgets/registration_identity_field.dart';
import 'package:keebox/features/authentication/widgets/registration_sign_in_link.dart';

class RegistrationIdentityScreen extends StatefulWidget {
  const RegistrationIdentityScreen({
    required this.identity,
    required this.onNext,
    required this.onSignIn,
    this.errors = const {},
    super.key,
  });
  final RegistrationIdentity identity;
  final ValueChanged<RegistrationIdentity> onNext;
  final VoidCallback onSignIn;
  final Map<String, String?> errors;
  @override
  State<RegistrationIdentityScreen> createState() =>
      _RegistrationIdentityScreenState();
}

class _RegistrationIdentityScreenState
    extends State<RegistrationIdentityScreen> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.identity.firstName);
  late final _last = TextEditingController(text: widget.identity.lastName);
  late final _email = TextEditingController(text: widget.identity.email);
  final _edited = <String>{};
  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  void _next() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    widget.onNext((
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      email: _email.text.trim(),
    ));
  }

  String? _nameError(String? value, String requiredMessage) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return requiredMessage;
    return name.runes.length > 150 ? AppTexts.registrationNameTooLong : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(automaticallyImplyLeading: false, toolbarHeight: 78.h),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.fromLTRB(26.w, 17.h, 26.w, 20.h),
                child: Column(
                  children: [
                    const RegistrationHeader(
                      image: AppAssets.registrationIdentity,
                      title: AppTexts.registrationIdentityTitle,
                      subtitle: AppTexts.registrationIdentitySubtitle,
                    ),
                    SizedBox(height: 32.h),
                    Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            RegistrationIdentityField(
                              controller: _first,
                              hint: AppTexts.registrationFirstNameHint,
                              icon: AppAssets.user,
                              autofillHint: AutofillHints.givenName,
                              errorText: _edited.contains('first_name')
                                  ? null
                                  : widget.errors['first_name'],
                              onChanged: (_) =>
                                  setState(() => _edited.add('first_name')),
                              validator: (value) => _nameError(
                                value,
                                AppTexts.registrationFirstNameRequired,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            RegistrationIdentityField(
                              controller: _last,
                              hint: AppTexts.registrationLastNameHint,
                              icon: AppAssets.user,
                              autofillHint: AutofillHints.familyName,
                              errorText: _edited.contains('last_name')
                                  ? null
                                  : widget.errors['last_name'],
                              onChanged: (_) =>
                                  setState(() => _edited.add('last_name')),
                              validator: (value) => _nameError(
                                value,
                                AppTexts.registrationLastNameRequired,
                              ),
                            ),
                            SizedBox(height: 14.h),
                            RegistrationIdentityField(
                              controller: _email,
                              hint: AppTexts.recoveryEmailHint,
                              icon: AppAssets.email,
                              autofillHint: AutofillHints.email,
                              email: true,
                              onSubmitted: _next,
                              errorText: _edited.contains('email')
                                  ? null
                                  : widget.errors['email'],
                              onChanged: (_) =>
                                  setState(() => _edited.add('email')),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return AppTexts.recoveryEmailRequired;
                                }
                                if (email.runes.length > 254) {
                                  return AppTexts.registrationEmailTooLong;
                                }
                                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(email)
                                    ? null
                                    : AppTexts.recoveryEmailInvalid;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 27.h),
                    SizedBox(
                      width: double.infinity,
                      child: RecoveryContinueButton(
                        onPressed: _next,
                        label: AppTexts.next,
                        iconGap: 6,
                      ),
                    ),
                    const Spacer(),
                    RegistrationSignInLink(onSignIn: widget.onSignIn),
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
