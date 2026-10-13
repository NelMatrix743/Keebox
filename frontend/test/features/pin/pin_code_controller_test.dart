import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/pin/state/pin_code_controller.dart';

void main() {
  late ProviderContainer container;
  late Object identity;
  late PinCodeController controller;

  setUp(() {
    container = ProviderContainer();
    identity = Object();
    container.listen(pinCodeControllerProvider(identity), (_, _) {});
    controller = container.read(pinCodeControllerProvider(identity).notifier);
  });
  tearDown(() => container.dispose());

  test(
    'only the fifth valid digit returns a complete PIN, preserving zeroes',
    () {
      expect(controller.enterDigit(-1), isNull);
      expect(controller.enterDigit(10), isNull);
      for (final digit in [0, 1, 2, 3]) {
        expect(controller.enterDigit(digit), isNull);
      }
      expect(controller.enterDigit(4), '01234');
      expect(controller.enterDigit(5), isNull);
      expect(container.read(pinCodeControllerProvider(identity)), '01234');
    },
  );

  test('delete removes the last digit and permits a corrected PIN', () {
    controller.deleteDigit();
    for (final digit in [0, 1, 2, 3, 4]) {
      controller.enterDigit(digit);
    }
    controller.deleteDigit();
    expect(controller.enterDigit(9), '01239');
    for (var index = 0; index < 6; index++) {
      controller.deleteDigit();
    }
    expect(container.read(pinCodeControllerProvider(identity)), isEmpty);
  });

  test('overlapping screens keep their PIN entries separate', () {
    controller.enterDigit(1);
    final secondIdentity = Object();
    container.listen(pinCodeControllerProvider(secondIdentity), (_, _) {});
    container
        .read(pinCodeControllerProvider(secondIdentity).notifier)
        .enterDigit(2);
    expect(container.read(pinCodeControllerProvider(identity)), '1');
    expect(container.read(pinCodeControllerProvider(secondIdentity)), '2');
  });
}
