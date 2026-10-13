import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/state/local_unlock_controller.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Hasher hasher;
  late _Storage storage;
  final provider = localUnlockControllerProvider(Object());

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    hasher = _Hasher();
    storage = _Storage();
    container = ProviderContainer(
      overrides: [
        localPinHasherProvider.overrideWithValue(hasher),
        localPinStorageProvider.overrideWithValue(storage),
      ],
    );
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result, verifiedPin: '01234');
    container.read(authenticationControllerProvider.notifier).lock();
    container.listen(provider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test(
    'wrong PIN reports remaining attempts and permits a successful retry',
    () async {
      final controller = container.read(provider.notifier);
      await controller.submit('99999');
      expect(
        container.read(provider).errorMessage,
        AppTexts.localPinIncorrect(4),
      );
      expect(container.read(provider).entryRevision, 1);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
      await controller.submit('01234');
      expect(container.read(provider).isUnlocked, isTrue);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedUnlocked>(),
      );
      expect((await storage.read('user'))!.failedAttempts, 0);
      expect(
        (await container.read(authenticatedUserStorageProvider).read('user'))!
            .kbkey,
        'permanent-key',
      );
    },
  );

  test('fifth incorrect attempt requires backend authentication', () async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await container.read(provider.notifier).submit('99999');
    }
    expect(container.read(provider).requiresLogin, isTrue);
    expect(
      container.read(provider).errorMessage,
      AppTexts.localPinLoginRequired,
    );
    expect((await storage.read('user'))!.requiresReauthentication, isTrue);
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
    expect(
      (await container.read(authenticatedUserStorageProvider).read('user'))!
          .kbkey,
      'permanent-key',
    );
  });

  for (final failure in ['missing', 'corrupt']) {
    test('$failure verifier requires backend authentication', () async {
      storage.failure = failure;
      await container.read(provider.notifier).submit('01234');
      expect(container.read(provider).requiresLogin, isTrue);
      expect(
        container.read(provider).errorMessage,
        AppTexts.localPinLoginRequired,
      );
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
    });
  }

  for (final failure in ['read', 'write']) {
    test('$failure failure remains locked and allows a retry', () async {
      storage.failure = failure;
      await container
          .read(provider.notifier)
          .submit(failure == 'write' ? '99999' : '01234');
      expect(
        container.read(provider).errorMessage,
        AppTexts.pinVerificationFailed,
      );
      expect(container.read(provider).isSubmitting, isFalse);
      expect(container.read(provider).requiresLogin, isFalse);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
      storage.failure = null;
      await container.read(provider.notifier).submit('01234');
      expect(container.read(provider).isUnlocked, isTrue);
    });
  }

  test('incomplete or non-ASCII PINs do not consume attempts', () async {
    final calls = hasher.calls;
    for (final pin in ['1234', '123456', 'abcde', '١٢٣٤٥']) {
      await container.read(provider.notifier).submit(pin);
    }
    expect(hasher.calls, calls);
    expect((await storage.read('user'))!.failedAttempts, 0);
    expect(container.read(provider).errorMessage, isNull);
  });

  test(
    'duplicate submissions are ignored while verification is pending',
    () async {
      hasher.pause();
      final controller = container.read(provider.notifier);
      final calls = hasher.calls;
      final first = controller.submit('01234');
      await hasher.started!.future;
      await controller.submit('99999');
      expect(container.read(provider).isSubmitting, isTrue);
      expect(hasher.calls, calls + 1);
      hasher.gate!.complete();
      await first;
      expect(container.read(provider).isUnlocked, isTrue);
    },
  );

  test(
    'disposing the screen controller cannot unlock on a late match',
    () async {
      hasher.pause();
      final operation = container.read(provider.notifier).submit('01234');
      await hasher.started!.future;
      container.invalidate(provider);
      hasher.gate!.complete();
      await operation;
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
      expect(container.read(provider).isUnlocked, isFalse);
    },
  );

  test(
    'a new lock during verification cancels screen success and clears entry',
    () async {
      hasher.pause();
      final operation = container.read(provider.notifier).submit('01234');
      await hasher.started!.future;
      container.read(authenticationControllerProvider.notifier).lock();
      hasher.gate!.complete();
      await operation;
      expect(container.read(provider).isUnlocked, isFalse);
      expect(container.read(provider).isSubmitting, isFalse);
      expect(container.read(provider).entryRevision, 1);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
    },
  );

  test('leaving before a queued verification starts skips hashing', () async {
    var active = true;
    final calls = hasher.calls;
    final operation = container
        .read(authenticationControllerProvider.notifier)
        .verifyLocalPin('01234', isActive: () => active);
    active = false;
    await operation;
    expect(hasher.calls, calls);
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<AuthenticatedLocked>(),
    );
  });
}

const _result = AuthenticationResult(
  user: AuthenticatedUser(
    id: 'user',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: 'permanent-key',
  ),
  session: AuthenticationSession(
    userId: 'user',
    accessToken: 'access',
    refreshToken: 'refresh',
  ),
  message: 'Completed.',
);

class _Hasher extends LocalPinHasher {
  int calls = 0;
  Completer<void>? gate;
  Completer<void>? started;
  void pause() {
    gate = Completer<void>();
    started = Completer<void>();
  }

  @override
  Future<List<int>> derive(String pin, List<int> salt) async {
    calls++;
    if (gate != null) {
      if (!started!.isCompleted) started!.complete();
      await gate!.future;
    }
    return List.generate(32, (index) => pin.codeUnitAt(index % pin.length));
  }
}

class _Storage extends LocalPinStorage {
  _Storage() : super(storage: const FlutterSecureStorage());
  String? failure;
  @override
  Future<LocalPinRecord?> read(String userId) async {
    switch (failure) {
      case 'missing':
        return null;
      case 'corrupt':
        throw const FormatException('Invalid record');
      case 'read':
        throw StateError('Storage unavailable');
    }
    return super.read(userId);
  }

  @override
  Future<void> save(LocalPinRecord record) async {
    if (failure == 'write') throw StateError('Storage unavailable');
    await super.save(record);
  }
}
