import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/state/onboarding_controller.dart';
import 'package:keebox/features/onboarding/state/onboarding_state.dart';
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
  OnboardingController controller() =>
      container.read(onboardingControllerProvider.notifier);
  OnboardingState progress() =>
      container.read(onboardingControllerProvider).requireValue;

  test(
    'forward visits the four introductions and welcome without completing',
    () async {
      expect(
        (await container.read(onboardingControllerProvider.future)).step,
        OnboardingStep.notes,
      );
      expect(progress().canGoBack, isFalse);
      for (final step in OnboardingStep.values.skip(1)) {
        expect(progress().canGoForward, isTrue);
        controller().next();
        expect(progress().step, step);
      }
      controller().next();
      expect(progress().isWelcome, isTrue);
      expect(progress().canGoForward, isFalse);
      expect(progress().isCompleted, isFalse);
      expect(storage.writes, 0);
    },
  );

  test('Skip jumps directly to welcome from every introduction', () async {
    await container.read(onboardingControllerProvider.future);
    for (var page = 0; page < OnboardingStep.welcome.index; page++) {
      controller().setPage(page);
      controller().skip();
      expect(progress().step, OnboardingStep.welcome);
      expect(progress().isCompleted, isFalse);
    }
    controller().skip();
    expect(progress().step, OnboardingStep.welcome);
    expect(storage.writes, 0);
  });

  test(
    'Back walks to the previous state and stops at the first introduction',
    () async {
      await container.read(onboardingControllerProvider.future);
      controller().skip();
      for (final step in OnboardingStep.values.reversed.skip(1)) {
        expect(progress().canGoBack, isTrue);
        controller().previous();
        expect(progress().step, step);
      }
      controller().previous();
      expect(progress().step, OnboardingStep.notes);
      expect(progress().canGoBack, isFalse);
      expect(storage.writes, 0);
    },
  );

  test('swipe selection shares progression with the forward button', () async {
    await container.read(onboardingControllerProvider.future);
    controller().setPage(OnboardingStep.privacy.index);
    expect(progress().step, OnboardingStep.privacy);
    controller().next();
    expect(progress().step, OnboardingStep.backup);
    controller().setPage(OnboardingStep.credentials.index);
    expect(progress().step, OnboardingStep.credentials);
    for (final invalid in [-1, OnboardingStep.values.length, 999]) {
      controller().setPage(invalid);
      expect(progress().step, OnboardingStep.credentials);
    }
    expect(storage.writes, 0);
  });

  test(
    'unfinished progress is in memory and restarts at the first introduction',
    () async {
      await container.read(onboardingControllerProvider.future);
      controller().setPage(OnboardingStep.backup.index);
      container.invalidate(onboardingControllerProvider);
      expect(
        (await container.read(onboardingControllerProvider.future)).step,
        OnboardingStep.notes,
      );
      expect(storage.writes, 0);
    },
  );

  test('navigation is ignored while preferences are loading', () async {
    storage.readGate = Completer<bool>();
    final ready = container.read(onboardingControllerProvider.future);
    controller().next();
    controller().previous();
    controller().skip();
    controller().setPage(OnboardingStep.privacy.index);
    storage.readGate!.complete(false);
    expect((await ready).step, OnboardingStep.notes);
    expect(storage.writes, 0);
  });

  test('navigation is blocked during and after completion', () async {
    await container.read(onboardingControllerProvider.future);
    controller().skip();
    storage.writeGate = Completer<void>();
    final saved = controller().complete();
    expect(progress().isSaving, isTrue);
    expect(progress().canGoBack, isFalse);
    expect(progress().canGoForward, isFalse);
    void attemptNavigation() {
      controller().previous();
      controller().next();
      controller().skip();
      controller().setPage(0);
      expect(progress().step, OnboardingStep.welcome);
    }

    attemptNavigation();
    storage.writeGate!.complete();
    expect(await saved, isTrue);
    expect(progress().isCompleted, isTrue);
    attemptNavigation();
    expect(storage.writes, 1);
  });
}

class _Storage implements OnboardingStorage {
  int writes = 0;
  Completer<bool>? readGate;
  Completer<void>? writeGate;
  @override
  Future<bool> isCompleted() async =>
      readGate == null ? false : await readGate!.future;
  @override
  Future<void> markCompleted() async {
    writes++;
    if (writeGate != null) await writeGate!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
