import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/pin/state/pin_setup_controller.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';

void main() {
  late ProviderContainer container;
  late Object screen;
  late PinSetupController controller;

  setUp(() {
    container = ProviderContainer();
    screen = Object();
    container.listen(pinSetupControllerProvider(screen), (_, _) {});
    controller = container.read(pinSetupControllerProvider(screen).notifier);
  });
  tearDown(() => container.dispose());

  PinSetupState current() => container.read(pinSetupControllerProvider(screen));
  void enter(String pin) {
    for (final digit in pin.split('')) {
      controller.enterDigit(int.parse(digit));
    }
  }

  test('entry preserves leading zeroes and stops at five digits', () {
    controller.enterDigit(-1);
    controller.enterDigit(10);
    enter('0123456');
    expect(current().digits, '01234');
    expect(current().canConfirm, isTrue);
  });

  test('delete removes the last digit and allows the slot to be reused', () {
    controller.deleteDigit();
    enter('01234');
    controller.deleteDigit();
    expect(current().digits, '0123');
    expect(current().canConfirm, isFalse);
    controller.enterDigit(9);
    expect(current().digits, '01239');
    for (var i = 0; i < 6; i++) {
      controller.deleteDigit();
    }
    expect(current().digits, isEmpty);
  });

  test('incomplete PIN never advances or invokes completion', () async {
    enter('1234');
    var called = false;
    await controller.confirm((_) => called = true);
    expect(called, isFalse);
    expect(current().stage, PinSetupStage.entry);
  });

  test(
    'first confirmation clears entry and matching second entry completes',
    () async {
      final submitted = <String>[];
      enter('01234');
      await controller.confirm(submitted.add);
      expect(current().stage, PinSetupStage.confirmation);
      expect(current().digits, isEmpty);
      expect(submitted, isEmpty);
      enter('01234');
      await controller.confirm(submitted.add);
      expect(submitted, ['01234']);
      expect(current().stage, PinSetupStage.complete);
      expect(current().digits, isEmpty);
      controller.enterDigit(9);
      await controller.confirm(submitted.add);
      expect(submitted, hasLength(1));
      expect(current().canConfirm, isFalse);
    },
  );

  test('mismatch clears confirmation and permits a matching retry', () async {
    String? submitted;
    enter('12345');
    await controller.confirm((pin) => submitted = pin);
    enter('54321');
    await controller.confirm((pin) => submitted = pin);
    expect(current().error, PinSetupError.mismatch);
    expect(current().digits, isEmpty);
    expect(submitted, isNull);
    enter('12345');
    expect(current().error, isNull);
    await controller.confirm((pin) => submitted = pin);
    expect(submitted, '12345');
  });

  test('pending callback blocks editing and duplicate confirmation', () async {
    enter('12345');
    await controller.confirm((_) {});
    enter('12345');
    final pending = Completer<void>();
    var calls = 0;
    Future<void> submit(String _) {
      calls++;
      return pending.future;
    }

    final confirmation = controller.confirm(submit);
    controller.deleteDigit();
    controller.enterDigit(9);
    await controller.confirm(submit);
    expect(current().digits, '12345');
    expect(current().isSubmitting, isTrue);
    expect(calls, 1);
    pending.complete();
    await confirmation;
    expect(current().stage, PinSetupStage.complete);
  });

  test('callback failure allows confirmation to be retried', () async {
    enter('12345');
    await controller.confirm((_) {});
    enter('12345');
    await controller.confirm((_) => throw StateError('Unavailable'));
    expect(current().error, PinSetupError.submission);
    expect(current().isSubmitting, isFalse);
    enter('12345');
    await controller.confirm((_) {});
    expect(current().stage, PinSetupStage.complete);
  });

  test('separate screen instances keep independent entries', () {
    enter('123');
    final other = Object();
    container.listen(pinSetupControllerProvider(other), (_, _) {});
    final otherController = container.read(
      pinSetupControllerProvider(other).notifier,
    );
    otherController.enterDigit(9);
    expect(current().digits, '123');
    expect(container.read(pinSetupControllerProvider(other)).digits, '9');
  });

  test('second confirmation stays busy before mismatch validation', () async {
    enter('12345');
    await controller.confirm((_) {});
    enter('54321');
    final rendered = Completer<void>();
    var submitted = false;
    final confirmation = controller.confirm(
      (_) => submitted = true,
      beforeValidation: () => rendered.future,
    );
    expect(current().isSubmitting, isTrue);
    expect(current().canConfirm, isFalse);
    expect(current().error, isNull);
    controller.deleteDigit();
    expect(current().digits, '54321');
    rendered.complete();
    await confirmation;
    expect(submitted, isFalse);
    expect(current().isSubmitting, isFalse);
    expect(current().error, PinSetupError.mismatch);
    expect(current().digits, isEmpty);
  });

  test('leaving before validation prevents the completion callback', () async {
    enter('12345');
    await controller.confirm((_) {});
    enter('12345');
    final rendered = Completer<void>();
    var submitted = false;
    final confirmation = controller.confirm(
      (_) => submitted = true,
      beforeValidation: () => rendered.future,
    );
    container.invalidate(pinSetupControllerProvider(screen));
    await container.pump();
    rendered.complete();
    await confirmation;
    expect(submitted, isFalse);
    expect(current().stage, PinSetupStage.entry);
  });

  test('leaving during completion safely disposes the PIN flow', () async {
    enter('12345');
    await controller.confirm((_) {});
    enter('12345');
    final pending = Completer<void>();
    final confirmation = controller.confirm((_) => pending.future);
    container.invalidate(pinSetupControllerProvider(screen));
    pending.complete();
    await confirmation;
    expect(current().stage, PinSetupStage.entry);
    expect(current().digits, isEmpty);
  });
}
