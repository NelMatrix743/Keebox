import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/recovery/models/recovery_challenge.dart';
import 'package:keebox/features/authentication/recovery/models/recovery_resend_request.dart';
import 'package:keebox/features/authentication/recovery/models/recovery_start_request.dart';
import 'package:keebox/features/authentication/recovery/models/recovery_type.dart';
import 'package:keebox/features/authentication/recovery/models/recovery_verified.dart';
import 'package:keebox/features/authentication/recovery/models/recovery_verify_request.dart';
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
}
