import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/models/recovery_requests.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';

final recoveryApiProvider = Provider<RecoveryAPI>((ref) {
  return RecoveryAPI(client: ref.watch(apiClientProvider));
});

class RecoveryAPI {
  const RecoveryAPI({required this.client});
  final APIClient client;

  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async {
    final endpoint = switch (type) {
      RecoveryType.password => APIEndpoints.resetPassword,
      RecoveryType.pin => APIEndpoints.resetPin,
    };
    final response = await client.post<RecoveryChallenge>(
      endpoint,
      data: request.toJson(),
      decode: RecoveryChallenge.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<RecoveryChallenge> resendOtp(
    RecoveryResendRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RecoveryChallenge>(
      APIEndpoints.resetResendOtp,
      data: request.toJson(),
      decode: RecoveryChallenge.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<RecoveryVerified> verifyOtp(
    RecoveryVerifyRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RecoveryVerified>(
      APIEndpoints.resetVerifyOtp,
      data: request.toJson(),
      decode: RecoveryVerified.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<RecoveryCompleted> completePassword(
    PasswordResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RecoveryCompleted>(
      APIEndpoints.resetPasswordComplete,
      data: request.toJson(),
      decode: RecoveryCompleted.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<RecoveryCompleted> completePin(
    PinResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RecoveryCompleted>(
      APIEndpoints.resetPinComplete,
      data: request.toJson(),
      decode: RecoveryCompleted.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }
}
