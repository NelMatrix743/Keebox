import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RecoveryOtpFields extends StatefulWidget {
  const RecoveryOtpFields({
    required this.onChanged,
    required this.onSubmitted,
    this.enabled = true,
    super.key,
  });
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool enabled;

  @override
  State<RecoveryOtpFields> createState() => _RecoveryOtpFieldsState();
}

class _RecoveryOtpFieldsState extends State<RecoveryOtpFields> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focus) {
      node.dispose();
    }
    super.dispose();
  }

  void _changed(int index, String value) {
    if (!widget.enabled) return;
    setState(() {
      if (value.length > 1) {
        final start = value.length == 6 ? 0 : index;
        for (
          var offset = 0;
          offset < value.length && start + offset < 6;
          offset++
        ) {
          _controllers[start + offset].text = value[offset];
        }
        final next = math.min(start + value.length, 5);
        _focus[next].requestFocus();
      } else if (value.isEmpty && index > 0) {
        _focus[index - 1].requestFocus();
      } else if (value.isNotEmpty && index < 5) {
        _focus[index + 1].requestFocus();
      }
    });
    widget.onChanged(_controllers.map((controller) => controller.text).join());
  }

  KeyEventResult _key(int index, KeyEvent event) {
    if (widget.enabled &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      setState(() => _controllers[index - 1].clear());
      _focus[index - 1].requestFocus();
      widget.onChanged(
        _controllers.map((controller) => controller.text).join(),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final height = math.max(
      51.h,
      MediaQuery.textScalerOf(context).scale(24.sp) * 1.5 + 8.h,
    );
    return AutofillGroup(
      child: Row(
        children: [
          for (var index = 0; index < 6; index++) ...[
            if (index > 0) SizedBox(width: 5.w),
            Expanded(
              child: Focus(
                onKeyEvent: (_, event) => _key(index, event),
                child: SizedBox(
                  height: height,
                  child: Semantics(
                    label: AppTexts.otpDigitLabel(index + 1),
                    child: TextField(
                      key: ValueKey('otp-digit-$index'),
                      controller: _controllers[index],
                      focusNode: _focus[index],
                      enabled: widget.enabled,
                      expands: true,
                      maxLines: null,
                      keyboardType: TextInputType.number,
                      textInputAction: index == 5
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autofillHints: index == 0
                          ? const [AutofillHints.oneTimeCode]
                          : null,
                      autocorrect: false,
                      enableSuggestions: false,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        fontFamily: AppFonts.poppins,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.5,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onTap: () =>
                          _controllers[index].selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: _controllers[index].text.length,
                          ),
                      onChanged: (value) => _changed(index, value),
                      onSubmitted: (_) => widget.onSubmitted(),
                      decoration: InputDecoration(
                        constraints: BoxConstraints.tightFor(height: height),
                        labelText: null,
                        hintText: null,
                        filled: true,
                        fillColor: _controllers[index].text.isEmpty
                            ? AppColors.border
                            : Colors.transparent,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: _border(
                          _controllers[index].text.isNotEmpty,
                        ),
                        disabledBorder: _border(
                          _controllers[index].text.isNotEmpty,
                        ),
                        focusedBorder: _border(true),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _border(bool filled) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8.r),
    borderSide: filled
        ? BorderSide(color: AppColors.brand, width: 2.r)
        : BorderSide.none,
  );
}
