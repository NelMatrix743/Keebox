import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/recovery_challenge.dart';
import 'package:keebox/features/authentication/models/recovery_verified.dart';
import 'package:keebox/features/authentication/models/recovery_completed.dart';

const resetId = '12345678-1234-1234-1234-123456789abc';

void main() {
  final pending = <String, dynamic>{
    'reset_id': resetId,
    'status': 'otp_pending',
    'otp_expires_at': '2026-10-18T12:05:00Z',
    'resend_available_at': '2026-10-18T12:01:00Z',
    'message': 'Generic message',
  };
  final verified = <String, dynamic>{
    'reset_id': resetId,
    'status': 'otp_verified',
    'completion_expires_at': '2026-10-18T14:10:00+02:00',
    'message': 'Verified',
  };
  final completed = <String, dynamic>{
    'reset_id': resetId,
    'status': 'completed',
    'message': 'Sign in again',
  };
  test('start and resend decode the identical pending contract', () {
    final response = RecoveryChallenge.fromJson(pending);
    expect(response.resetId, resetId);
    expect(response.otpExpiresAt, DateTime.utc(2026, 10, 18, 12, 5));
    expect(response.resendAvailableAt, DateTime.utc(2026, 10, 18, 12, 1));
    expect(response.message, 'Generic message');
  });
  test('verified completion deadline normalizes timezone offsets to UTC', () {
    final response = RecoveryVerified.fromJson(verified);
    expect(response.resetId, resetId);
    expect(response.completionExpiresAt, DateTime.utc(2026, 10, 18, 12, 10));
  });
  test('completion decodes confirmation without requiring credentials', () {
    final response = RecoveryCompleted.fromJson(completed);
    expect(response.resetId, resetId);
    expect(response.message, 'Sign in again');
  });
  final decoders = <String, Object Function(Object?)>{
    'pending': RecoveryChallenge.fromJson,
    'verified': RecoveryVerified.fromJson,
    'completed': RecoveryCompleted.fromJson,
  };
  final payloads = {
    'pending': pending,
    'verified': verified,
    'completed': completed,
  };
  for (final entry in decoders.entries) {
    test(
      '${entry.key} rejects invalid structures, IDs, missing fields and wrong stages',
      () {
        final original = payloads[entry.key]!;
        for (final malformed in <Object?>[
          null,
          [],
          'bad',
          {...original, 'reset_id': 'bad'},
          {...original, 'status': 'wrong'},
          {...original, 'message': 5},
          {...original}..remove('reset_id'),
          {...original}..remove('message'),
        ]) {
          expect(() => entry.value(malformed), throwsFormatException);
        }
      },
    );
  }
  for (final timestamp in ['bad', '2026-10-18T12:00:00', '', null, 123]) {
    test('rejects malformed or timezone-less timestamps: $timestamp', () {
      expect(
        () => RecoveryChallenge.fromJson({
          ...pending,
          'otp_expires_at': timestamp,
        }),
        throwsFormatException,
      );
      expect(
        () => RecoveryChallenge.fromJson({
          ...pending,
          'resend_available_at': timestamp,
        }),
        throwsFormatException,
      );
      expect(
        () => RecoveryVerified.fromJson({
          ...verified,
          'completion_expires_at': timestamp,
        }),
        throwsFormatException,
      );
    });
  }
}
