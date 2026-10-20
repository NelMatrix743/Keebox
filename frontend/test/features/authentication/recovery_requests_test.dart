import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/recovery_start_request.dart';
import 'package:keebox/features/authentication/models/recovery_resend_request.dart';
import 'package:keebox/features/authentication/models/recovery_verify_request.dart';
import 'package:keebox/features/authentication/models/password_reset_request.dart';
import 'package:keebox/features/authentication/models/pin_reset_request.dart';

const resetId = '12345678-1234-1234-1234-123456789abc';

void main() {
  test('start trims email without adding a recovery type to the payload', () {
    expect(const RecoveryStartRequest(email: ' ada@example.com ').toJson(), {
      'email': 'ada@example.com',
    });
  });
  test('resend sends only the reset ID', () {
    expect(const RecoveryResendRequest(resetId: resetId).toJson(), {
      'reset_id': resetId,
    });
  });
  test('verification preserves OTP leading zeroes', () {
    expect(
      const RecoveryVerifyRequest(resetId: resetId, otpCode: '001234').toJson(),
      {'reset_id': resetId, 'otp_code': '001234'},
    );
  });
  test('password completion preserves password whitespace', () {
    expect(
      const PasswordResetRequest(
        resetId: resetId,
        newPassword: ' password ',
      ).toJson(),
      {'reset_id': resetId, 'new_password': ' password '},
    );
  });
  test('PIN completion preserves leading zeroes', () {
    expect(const PinResetRequest(resetId: resetId, newPin: '00123').toJson(), {
      'reset_id': resetId,
      'new_pin': '00123',
    });
  });
  for (final otp in [
    '12345',
    '1234567',
    '١٢٣٤٥٦',
    '12345\n',
    ' 01234',
    'abcdef',
  ]) {
    test('rejects invalid OTP ${otp.codeUnits}', () {
      expect(
        () => RecoveryVerifyRequest(resetId: resetId, otpCode: otp).toJson(),
        throwsFormatException,
      );
    });
  }
  for (final pin in ['1234', '123456', '١٢٣٤٥', '1234\n', ' 0123', 'abcde']) {
    test('rejects invalid PIN ${pin.codeUnits}', () {
      expect(
        () => PinResetRequest(resetId: resetId, newPin: pin).toJson(),
        throwsFormatException,
      );
    });
  }
  test('rejects missing email, empty password, and invalid challenge IDs', () {
    expect(
      () => const RecoveryStartRequest(email: ' ').toJson(),
      throwsFormatException,
    );
    expect(
      () => const PasswordResetRequest(
        resetId: resetId,
        newPassword: '',
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => const RecoveryResendRequest(resetId: '').toJson(),
      throwsFormatException,
    );
    expect(
      () => const RecoveryVerifyRequest(
        resetId: 'bad',
        otpCode: '123456',
      ).toJson(),
      throwsFormatException,
    );
    expect(
      () => const PinResetRequest(resetId: 'bad', newPin: '12345').toJson(),
      throwsFormatException,
    );
    expect(
      () => const PasswordResetRequest(
        resetId: 'bad',
        newPassword: 'password',
      ).toJson(),
      throwsFormatException,
    );
  });
}
