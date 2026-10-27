import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';

const _id = '12345678-1234-1234-1234-123456789abc';

void main() {
  final pending = <String, dynamic>{
    'registration_id': _id,
    'status': 'otp_pending',
    'expires_at': '2026-10-27T12:30:00Z',
    'otp_expires_at': '2026-10-27T14:05:00+02:00',
    'resend_available_at': '2026-10-27T12:01:00Z',
    'message': 'Check your email.',
  };
  final verified = <String, dynamic>{
    'registration_id': _id,
    'status': 'otp_verified',
    'message': 'Create your PIN.',
  };
  final resent = <String, dynamic>{
    'registration_id': _id,
    'status': 'otp_pending',
    'otp_expires_at': '2026-10-27T12:06:00Z',
    'resend_available_at': '2026-10-27T12:02:00Z',
    'resends_remaining': 2,
    'message': 'New code sent.',
  };

  test(
    'pending challenge keeps registration and OTP deadlines distinct in UTC',
    () {
      final result = RegistrationChallenge.fromJson(pending);
      expect(result.registrationId, _id);
      expect(result.expiresAt, DateTime.utc(2026, 10, 27, 12, 30));
      expect(result.otpExpiresAt, DateTime.utc(2026, 10, 27, 12, 5));
      expect(result.resendAvailableAt, DateTime.utc(2026, 10, 27, 12, 1));
      expect(result.message, 'Check your email.');
    },
  );
  test('verification requires no fabricated completion deadline', () {
    final result = RegistrationVerified.fromJson(verified);
    expect(result.registrationId, _id);
    expect(result.message, 'Create your PIN.');
  });
  test('resend decodes updated OTP timing without requiring a registration deadline', () {
    final result = RegistrationOtpResent.fromJson(resent);
    expect(result.registrationId, _id);
    expect(result.otpExpiresAt, DateTime.utc(2026, 10, 27, 12, 6));
    expect(result.resendAvailableAt, DateTime.utc(2026, 10, 27, 12, 2));
    expect(result.resendsRemaining, 2);
    expect(result.message, 'New code sent.');
    expect(
      RegistrationOtpResent.fromJson({...resent, 'resends_remaining': 0})
          .resendsRemaining,
      0,
    );
  });
  final cases = [
    (RegistrationChallenge.fromJson, pending),
    (RegistrationVerified.fromJson, verified),
    (RegistrationOtpResent.fromJson, resent),
  ];
  for (var i = 0; i < cases.length; i++) {
    final (decode, original) = cases[i];
    test(
      'response $i rejects malformed data, IDs, missing fields and wrong stages',
      () {
        for (final malformed in <Object?>[
          null,
          [],
          'bad',
          {...original, 'registration_id': 'bad'},
          {...original, 'registration_id': '$_id\n'},
          {...original, 'status': 'completed'},
          {...original, 'message': 3},
          for (final key in original.keys) {...original}..remove(key),
        ]) {
          expect(() => decode(malformed), throwsFormatException);
        }
      },
    );
  }
  for (final value in ['bad', '2026-10-27T12:00:00', '', null, 123]) {
    test('timestamp fields reject invalid or timezone-less values: $value', () {
      for (final key in [
        'expires_at',
        'otp_expires_at',
        'resend_available_at',
      ]) {
        expect(
          () => RegistrationChallenge.fromJson({...pending, key: value}),
          throwsFormatException,
        );
      }
      for (final key in ['otp_expires_at', 'resend_available_at']) {
        expect(
          () => RegistrationOtpResent.fromJson({...resent, key: value}),
          throwsFormatException,
        );
      }
    });
  }
  test('resend allowance must be a nonnegative integer', () {
    for (final value in [-1, 1.5, '2', null, true]) {
      expect(
        () => RegistrationOtpResent.fromJson({
          ...resent,
          'resends_remaining': value,
        }),
        throwsFormatException,
      );
    }
  });
  test('registration completion uses the shared user and session result', () {
    final result = AuthenticationResult.fromJson({
      'user_id': _id,
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'email': 'ada@example.com',
      'kbkey': 'permanent-key',
      'access_token': 'access',
      'refresh_token': 'refresh',
      'status': 'completed',
      'message': 'Registration completed successfully.',
    });
    expect(result.user.id, _id);
    expect(result.user.kbkey, 'permanent-key');
    expect(result.session.userId, _id);
    expect(result.session.accessToken, 'access');
    expect(result.session.refreshToken, 'refresh');
  });
}
