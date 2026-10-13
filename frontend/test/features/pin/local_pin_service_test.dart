import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_service.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late FakeLocalPinHasher hasher;
  late LocalPinService service;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = _Storage();
    hasher = FakeLocalPinHasher();
    service = LocalPinService(storage: storage, hasher: hasher);
  });

  test(
    'enrolled leading-zero PIN verifies offline and accounts stay separate',
    () async {
      await service.enrollVerifiedPin('first', '01234');
      await service.enrollVerifiedPin('second', '54321');
      expect(
        (await service.verify('first', '01234')).status,
        LocalPinStatus.matched,
      );
      expect(
        (await service.verify('second', '01234')).status,
        LocalPinStatus.incorrect,
      );
      expect((await storage.read('first'))!.failedAttempts, 0);
      expect((await storage.read('second'))!.failedAttempts, 1);
      final values = await storage.storage.readAll();
      expect(
        values.values.any(
          (value) => value.contains('01234') || value.contains('54321'),
        ),
        isFalse,
      );
    },
  );

  test('fifth failure persists reauthentication and blocks even the correct PIN after restart', () async {
    await service.enrollVerifiedPin('first', '01234');
    for (var attempt = 1; attempt <= 5; attempt++) {
      final result = await service.verify('first', '99999');
      expect(result.remainingAttempts, 5 - attempt);
      expect(
        result.status,
        attempt == 5
            ? LocalPinStatus.requiresReauthentication
            : LocalPinStatus.incorrect,
      );
    }
    final calls = hasher.calls;
    final restarted = LocalPinService(storage: _Storage(), hasher: hasher);
    expect(
      (await restarted.verify('first', '01234')).status,
      LocalPinStatus.requiresReauthentication,
    );
    expect(hasher.calls, calls);
  });

  test('correct PIN before the limit resets consecutive failures', () async {
    await service.enrollVerifiedPin('first', '01234');
    await service.verify('first', '99999');
    await service.verify('first', '99999');
    expect(
      (await service.verify('first', '01234')).status,
      LocalPinStatus.matched,
    );
    expect((await storage.read('first'))!.failedAttempts, 0);
  });

  test('successful backend enrollment replaces an obsolete PIN and clears the restriction', () async {
    await service.enrollVerifiedPin('first', '01234');
    for (var i = 0; i < 5; i++) {
      await service.verify('first', '99999');
    }
    await service.enrollVerifiedPin('first', '54321');
    expect(
      (await service.verify('first', '01234')).status,
      LocalPinStatus.incorrect,
    );
    expect(
      (await service.verify('first', '54321')).status,
      LocalPinStatus.matched,
    );
    expect((await storage.read('first'))!.requiresReauthentication, isFalse);
  });

  test(
    'missing and corrupt credentials require backend login without hashing',
    () async {
      expect(
        (await service.verify('missing', '01234')).status,
        LocalPinStatus.requiresReauthentication,
      );
      await storage.storage.write(
        key: 'keebox.pin.local.v1.first',
        value: '{corrupt',
      );
      expect(
        (await service.verify('first', '01234')).status,
        LocalPinStatus.requiresReauthentication,
      );
      expect(hasher.calls, 0);
    },
  );

  test('invalid input consumes no attempt', () async {
    await service.enrollVerifiedPin('first', '01234');
    expect(
      (await service.verify('first', '12345\n')).status,
      LocalPinStatus.invalidInput,
    );
    expect((await storage.read('first'))!.failedAttempts, 0);
  });

  test('concurrent failures cannot race past the attempt limit', () async {
    await service.enrollVerifiedPin('first', '01234');
    final results = await Future.wait(
      List.generate(8, (_) => service.verify('first', '99999')),
    );
    expect(
      results.where((result) => result.status == LocalPinStatus.incorrect),
      hasLength(4),
    );
    expect(
      results.where(
        (result) => result.status == LocalPinStatus.requiresReauthentication,
      ),
      hasLength(4),
    );
    expect((await storage.read('first'))!.failedAttempts, 5);
  });

  test(
    'cancellation during hashing cannot replace the existing verifier',
    () async {
      await service.enrollVerifiedPin('first', '01234');
      hasher.gate = Completer<void>();
      var active = true;
      final enrollment = service.enrollVerifiedPin(
        'first',
        '54321',
        isActive: () => active,
      );
      await Future<void>.delayed(Duration.zero);
      active = false;
      hasher.gate!.complete();
      expect(await enrollment, isFalse);
      hasher.gate = null;
      expect(
        (await service.verify('first', '01234')).status,
        LocalPinStatus.matched,
      );
    },
  );

  test('storage failure cannot report an unlocked device or a completed retry update', () async {
    await service.enrollVerifiedPin('first', '01234');
    await service.verify('first', '99999');
    storage.failSave = true;
    expect(
      (await service.verify('first', '01234')).status,
      LocalPinStatus.unavailable,
    );
    expect(
      (await service.verify('first', '99999')).status,
      LocalPinStatus.unavailable,
    );
    storage.failRead = true;
    expect(
      (await service.verify('first', '01234')).status,
      LocalPinStatus.unavailable,
    );
  });
}

class _Storage extends LocalPinStorage {
  _Storage() : super(storage: const FlutterSecureStorage());
  bool failRead = false;
  bool failSave = false;
  @override
  Future<LocalPinRecord?> read(String userId) {
    if (failRead) throw StateError('Read unavailable');
    return super.read(userId);
  }

  @override
  Future<void> save(LocalPinRecord record) {
    if (failSave) throw StateError('Write unavailable');
    return super.save(record);
  }
}

class FakeLocalPinHasher extends LocalPinHasher {
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<List<int>> derive(String pin, List<int> salt) async {
    calls++;
    if (gate != null) await gate!.future;
    return List<int>.generate(
      32,
      (index) => pin.codeUnitAt(index % pin.length),
    );
  }
}
