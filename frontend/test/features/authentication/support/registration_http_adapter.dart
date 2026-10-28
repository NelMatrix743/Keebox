import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:keebox/network/api_endpoints.dart';

import 'registration_fixture.dart';

/// Stateful server fixture; the real API client still serializes and decodes HTTP.
class RegistrationHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  DateTime now = DateTime.utc(2030);
  String otp = '001234';
  bool _started = false;
  bool _verified = false;
  bool _completed = false;
  bool loseCompletionResponse = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.data as Map<String, dynamic>?;
    if (options.path == APIEndpoints.register) {
      _started = true;
      return _response(201, {
        'registration_id': registrationId,
        'status': 'otp_pending',
        'expires_at': DateTime.utc(2030, 1, 1, 0, 30).toIso8601String(),
        ..._otpTiming(),
        'message': 'Check your email.',
      });
    }
    if (options.path == APIEndpoints.currentUser) {
      if (!_completed ||
          options.headers['Authorization'] != 'Bearer new-access') {
        return _failure(401, 'invalid_token');
      }
      return _response(200, {
        'user_id': registeredUser.id,
        'first_name': 'Augusta Ada',
        'last_name': registeredUser.lastName,
        'email': registeredUser.email,
      });
    }
    if (!_started || body?['registration_id'] != registrationId) {
      return _failure(409, 'invalid_registration_state');
    }
    if (options.path == APIEndpoints.registerResendOtp && !_verified) {
      otp = '009876';
      return _response(200, {
        'registration_id': registrationId,
        'status': 'otp_pending',
        ..._otpTiming(),
        'resends_remaining': 2,
        'message': 'Replacement code sent.',
      });
    }
    if (options.path == APIEndpoints.registerVerifyOtp && !_verified) {
      if (body?['otp_code'] != otp) return _failure(400, 'invalid_otp');
      _verified = true;
      return _response(200, {
        'registration_id': registrationId,
        'status': 'otp_verified',
        'message': 'Email verified.',
      });
    }
    if (options.path == APIEndpoints.registerCreatePin &&
        _verified &&
        !_completed) {
      _completed = true;
      if (loseCompletionResponse) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return _response(201, {
        'status': 'completed',
        'user_id': registeredUser.id,
        'first_name': registeredUser.firstName,
        'last_name': registeredUser.lastName,
        'email': registeredUser.email,
        'kbkey': registeredUser.kbkey,
        ...registeredResult.session.toJson(),
        'message': 'Registered.',
      });
    }
    return _failure(409, 'invalid_registration_state');
  }

  Map<String, String> _otpTiming() => {
    'otp_expires_at': now.add(const Duration(minutes: 5)).toIso8601String(),
    'resend_available_at': now
        .add(const Duration(minutes: 1))
        .toIso8601String(),
  };

  ResponseBody _failure(int status, String code) => ResponseBody.fromString(
    jsonEncode({
      'success': false,
      'data': null,
      'error': {'code': code, 'message': 'Request rejected.', 'details': null},
      'meta': null,
    }),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  ResponseBody _response(int status, Map<String, dynamic> data) =>
      ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': data,
          'error': null,
          'meta': null,
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
