import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/state/onboarding_controller.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';

void main() {
  late _Storage storage;
  late ProviderContainer container;

  setUp(() {
    storage = _Storage();
    container = ProviderContainer(
      overrides: [onboardingStorageProvider.overrideWithValue(storage)],
    );
  });
  tearDown(() => container.dispose());

  test('restores completion when the controller is recreated', () async {
    expect(
      (await container.read(onboardingControllerProvider.future)).isCompleted,
      isFalse,
    );
    container.read(onboardingControllerProvider.notifier).skip();
    await container.read(onboardingControllerProvider.notifier).complete();
    container.invalidate(onboardingControllerProvider);
    expect(
      (await container.read(onboardingControllerProvider.future)).isCompleted,
      isTrue,
    );
  });

  test('waits for persistence and prevents duplicate completion', () async {
    storage.gate = Completer<void>();
    await container.read(onboardingControllerProvider.future);
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.skip();
    final completion = controller.complete();
    expect(
      container.read(onboardingControllerProvider).requireValue.isSaving,
      isTrue,
    );
    expect(
      container.read(onboardingControllerProvider).requireValue.isCompleted,
      isFalse,
    );
    expect(await controller.complete(), isFalse);
    expect(storage.writes, 1);
    storage.gate!.complete();
    expect(await completion, isTrue);
    expect(
      container.read(onboardingControllerProvider).requireValue.isCompleted,
      isTrue,
    );
  });

  test('save failure retains incomplete state and permits retry', () async {
    storage.failSave = true;
    await container.read(onboardingControllerProvider.future);
    final controller = container.read(onboardingControllerProvider.notifier);
    controller.skip();
    expect(await controller.complete(), isFalse);
    final failed = container.read(onboardingControllerProvider).requireValue;
    expect(failed.isCompleted, isFalse);
    expect(failed.isSaving, isFalse);
    expect(failed.errorMessage, AppTexts.onboardingSaveFailed);
    expect(failed.step, OnboardingStep.welcome);
    storage.failSave = false;
    expect(await controller.complete(), isTrue);
    expect(
      container.read(onboardingControllerProvider).requireValue.step,
      OnboardingStep.welcome,
    );
    expect(
      container.read(onboardingControllerProvider).requireValue.errorMessage,
      isNull,
    );
  });

  test(
    'read failure exposes feedback and still permits recording completion',
    () async {
      storage.failRead = true;
      final initial = await container.read(onboardingControllerProvider.future);
      expect(initial.errorMessage, AppTexts.onboardingLoadFailed);
      container.read(onboardingControllerProvider.notifier).skip();
      expect(
        await container.read(onboardingControllerProvider.notifier).complete(),
        isTrue,
      );
      expect(storage.completed, isTrue);
    },
  );

  test('already completed onboarding does not write again', () async {
    storage.completed = true;
    await container.read(onboardingControllerProvider.future);
    expect(
      await container.read(onboardingControllerProvider.notifier).complete(),
      isTrue,
    );
    expect(storage.writes, 0);
  });

  test('disposed controller cannot report navigation readiness after a pending save', () async {
    storage.gate = Completer<void>();
    final scope = ProviderContainer(
      overrides: [onboardingStorageProvider.overrideWithValue(storage)],
    );
    await scope.read(onboardingControllerProvider.future);
    scope.read(onboardingControllerProvider.notifier).skip();
    final completion = scope
        .read(onboardingControllerProvider.notifier)
        .complete();
    scope.dispose();
    storage.gate!.complete();
    expect(await completion, isFalse);
  });

  test('only the welcome state can record onboarding completion', () async {
    await container.read(onboardingControllerProvider.future);
    final controller = container.read(onboardingControllerProvider.notifier);
    for (var page = 0; page < OnboardingStep.welcome.index; page++) {
      controller.setPage(page);
      expect(await controller.complete(), isFalse);
      expect(storage.writes, 0);
      expect(storage.completed, isFalse);
    }
    controller.skip();
    expect(await controller.complete(), isTrue);
    expect(storage.writes, 1);
  });
}

class _Storage implements OnboardingStorage {
  bool completed = false;
  bool failRead = false;
  bool failSave = false;
  int writes = 0;
  Completer<void>? gate;

  @override
  Future<bool> isCompleted() async {
    if (failRead) throw StateError('Read failed');
    return completed;
  }

  @override
  Future<void> markCompleted() async {
    writes++;
    if (gate != null) await gate!.future;
    if (failSave) throw StateError('Write failed');
    completed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
