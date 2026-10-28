import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';

final registrationApiProvider = Provider<RegistrationAPI>((ref) {
  return RegistrationAPI(client: ref.watch(apiClientProvider));
});

class RegistrationAPI {
  const RegistrationAPI({required this.client});

  final APIClient client;

  Future<RegistrationChallenge> start(
    RegistrationRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RegistrationChallenge>(
      APIEndpoints.register,
      data: request.toJson(),
      decode: RegistrationChallenge.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<RegistrationVerified> verifyOtp(
    RegistrationVerifyRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RegistrationVerified>(
      APIEndpoints.registerVerifyOtp,
      data: request.toJson(),
      decode: RegistrationVerified.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<RegistrationOtpResent> resendOtp(
    RegistrationResendRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<RegistrationOtpResent>(
      APIEndpoints.registerResendOtp,
      data: request.toJson(),
      decode: RegistrationOtpResent.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }
}
