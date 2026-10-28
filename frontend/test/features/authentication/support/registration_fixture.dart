import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/current_user_response.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/pin/local_pin_policy.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

const registeredUser = AuthenticatedUser(
  id: 'registered-user',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  kbkey: 'permanent-key',
);
const registeredResult = AuthenticationResult(
  user: registeredUser,
  session: AuthenticationSession(
    userId: 'registered-user',
    accessToken: 'new-access',
    refreshToken: 'new-refresh',
  ),
  message: 'Registered.',
);
const registrationDetails = RegistrationRequest(
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  password: 'strong password',
);
const registrationId = '12345678-1234-1234-1234-123456789abc';

class TestRegistrationAPI extends RegistrationAPI {
  TestRegistrationAPI() : super(client: APIClient());
  final pins = <String>[];
  APIException? failure;
  Completer<AuthenticationResult>? gate;
  @override
  Future<RegistrationChallenge> start(
    RegistrationRequest request, {
    CancelToken? cancelToken,
  }) async => RegistrationChallenge(
    registrationId: registrationId,
    expiresAt: DateTime.utc(2030, 1, 1, 0, 30),
    otpExpiresAt: DateTime.utc(2030, 1, 1, 0, 5),
    resendAvailableAt: DateTime.utc(2030, 1, 1, 0, 1),
    message: 'Check email.',
  );
  @override
  Future<RegistrationVerified> verifyOtp(
    RegistrationVerifyRequest request, {
    CancelToken? cancelToken,
  }) async => const RegistrationVerified(
    registrationId: registrationId,
    message: 'Verified.',
  );
  @override
  Future<AuthenticationResult> complete(
    RegistrationCompletionRequest request, {
    CancelToken? cancelToken,
  }) async {
    pins.add(request.pin);
    if (failure != null) throw failure!;
    return gate == null ? registeredResult : await gate!.future;
  }
}

class TestPinHasher extends LocalPinHasher {
  final started = Completer<void>();
  Completer<void>? gate;
  int failures = 0;
  final pins = <String>[];
  @override
  List<int> newSalt() => List.filled(LocalPinPolicy.saltLength, 1);
  @override
  Future<List<int>> derive(String pin, List<int> salt) async {
    pins.add(pin);
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    if (failures > 0) {
      failures--;
      throw StateError('Hasher unavailable');
    }
    return List.filled(
      LocalPinPolicy.verifierLength,
      pin.codeUnits.fold<int>(0, (sum, code) => sum + code) % 256,
    );
  }
}

class TestSessionStorage extends AuthenticationSessionStorage {
  TestSessionStorage() : super(storage: const FlutterSecureStorage());
  int failures = 0;
  int saves = 0;
  @override
  Future<void> save(AuthenticationSession session) async {
    saves++;
    await super.save(session);
    if (failures > 0) {
      failures--;
      throw StateError('Write confirmation failed');
    }
  }
}

class TestProfileAPI extends AuthenticationAPI {
  TestProfileAPI() : super(client: APIClient());
  int fetches = 0;
  @override
  Future<CurrentUserResponse> fetchCurrentUser() async {
    fetches++;
    return const CurrentUserResponse(
      id: 'registered-user',
      firstName: 'Ada',
      lastName: 'Lovelace',
      email: 'ada@example.com',
    );
  }
}
