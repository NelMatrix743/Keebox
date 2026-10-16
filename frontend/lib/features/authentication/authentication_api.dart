import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/current_user_response.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/models/login_pin_request.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/models/logout_response.dart';
import 'package:keebox/features/authentication/models/token_refresh_response.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';

final authenticationApiProvider = Provider<AuthenticationAPI>((ref) {
  return AuthenticationAPI(client: ref.watch(apiClientProvider));
});

class AuthenticationAPI {
  const AuthenticationAPI({required this.client});

  final APIClient client;

  Future<CurrentUserResponse> currentUser() async {
    final response = await client.get<CurrentUserResponse>(
      APIEndpoints.currentUser,
      authenticated: true,
      decode: CurrentUserResponse.fromJson,
    );
    return response.data;
  }

  Future<TokenRefreshResponse> refresh(String refreshToken) async {
    final response = await client.post<TokenRefreshResponse>(
      APIEndpoints.refresh,
      data: {'refresh_token': refreshToken},
      decode: TokenRefreshResponse.fromJson,
    );
    return response.data;
  }

  Future<LoginChallenge> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<LoginChallenge>(
      APIEndpoints.login,
      data: request.toJson(),
      decode: LoginChallenge.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<AuthenticationResult> verifyPin(
    LoginPinRequest request, {
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<AuthenticationResult>(
      APIEndpoints.loginVerifyPin,
      data: request.toJson(),
      decode: AuthenticationResult.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<LogoutResponse> logout({
    required String accessToken,
    CancelToken? cancelToken,
  }) async {
    final response = await client.post<LogoutResponse>(
      APIEndpoints.logout,
      headers: {'Authorization': 'Bearer $accessToken'},
      decode: LogoutResponse.fromJson,
      cancelToken: cancelToken,
    );
    return response.data;
  }
}
