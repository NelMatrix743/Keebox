import 'package:flutter_riverpod/flutter_riverpod.dart';

final pinCodeControllerProvider = NotifierProvider.autoDispose
    .family<PinCodeController, String, Object>((_) => PinCodeController());

class PinCodeController extends Notifier<String> {
  static const length = 5;

  @override
  String build() => '';

  String? enterDigit(int digit) {
    if (digit < 0 || digit > 9 || state.length == length) return null;
    state = '$state$digit';
    return state.length == length ? state : null;
  }

  void deleteDigit() {
    if (state.isEmpty) return;
    state = state.substring(0, state.length - 1);
  }
}
