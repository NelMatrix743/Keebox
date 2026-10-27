import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';

const _id = '12345678-1234-1234-1234-123456789abc';

void main() {
  test(
    'registration trims identity fields and preserves the password exactly',
    () {
      expect(
        const RegistrationRequest(
          firstName: ' Ada ',
          lastName: ' Lovelace ',
          email: ' ada@example.com ',
          password: ' password ',
        ).toJson(),
        {
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'email': 'ada@example.com',
          'password': ' password ',
        },
      );
    },
  );

  test('registration rejects missing and oversized identity fields', () {
    for (final request in [
      const RegistrationRequest(
        firstName: ' ',
        lastName: 'L',
        email: 'a@b.com',
        password: 'secret',
      ),
      const RegistrationRequest(
        firstName: 'A',
        lastName: ' ',
        email: 'a@b.com',
        password: 'secret',
      ),
      const RegistrationRequest(
        firstName: 'A',
        lastName: 'L',
        email: ' ',
        password: 'secret',
      ),
      const RegistrationRequest(
        firstName: 'A',
        lastName: 'L',
        email: 'a@b.com',
        password: '',
      ),
      RegistrationRequest(
        firstName: 'a' * 151,
        lastName: 'L',
        email: 'a@b.com',
        password: 'secret',
      ),
      RegistrationRequest(
        firstName: 'A',
        lastName: 'a' * 151,
        email: 'a@b.com',
        password: 'secret',
      ),
      RegistrationRequest(
        firstName: 'A',
        lastName: 'L',
        email: 'a' * 255,
        password: 'secret',
      ),
    ]) {
      expect(request.toJson, throwsFormatException);
    }
  });

  test(
    'identity length limits count Unicode characters rather than UTF-16 units',
    () {
      final name = '𐐀' * 150;
      expect(
        RegistrationRequest(
          firstName: name,
          lastName: name,
          email: 'a' * 254,
          password: 'secret',
        ).toJson()['first_name'],
        name,
      );
    },
  );

  test('resend sends only the registration ID', () {
    expect(const RegistrationResendRequest(registrationId: _id).toJson(), {
      'registration_id': _id,
    });
  });

  test('verification and completion preserve leading zeroes', () {
    expect(
      const RegistrationVerifyRequest(
        registrationId: _id,
        otpCode: '001234',
      ).toJson(),
      {'registration_id': _id, 'otp_code': '001234'},
    );
    expect(
      const RegistrationCompletionRequest(
        registrationId: _id,
        pin: '00123',
      ).toJson(),
      {'registration_id': _id, 'pin': '00123'},
    );
  });

  for (final code in [
    '',
    '12345',
    '1234567',
    '١٢٣٤٥٦',
    '12345\n',
    '123456\n',
    ' 12345',
    'abcdef',
  ]) {
    test('rejects invalid OTP ${code.codeUnits}', () {
      expect(
        () => RegistrationVerifyRequest(
          registrationId: _id,
          otpCode: code,
        ).toJson(),
        throwsFormatException,
      );
    });
  }
  for (final pin in [
    '',
    '1234',
    '123456',
    '١٢٣٤٥',
    '1234\n',
    '12345\n',
    ' 1234',
    'abcde',
  ]) {
    test('rejects invalid PIN ${pin.codeUnits}', () {
      expect(
        () => RegistrationCompletionRequest(
          registrationId: _id,
          pin: pin,
        ).toJson(),
        throwsFormatException,
      );
    });
  }
  for (final id in [
    '',
    'bad',
    ' $_id',
    '$_id\n',
    '12345678-1234-1234-1234-123456789abg',
  ]) {
    test(
      'all challenge requests reject invalid registration ID ${id.codeUnits}',
      () {
        expect(
          () => RegistrationResendRequest(registrationId: id).toJson(),
          throwsFormatException,
        );
        expect(
          () => RegistrationVerifyRequest(
            registrationId: id,
            otpCode: '123456',
          ).toJson(),
          throwsFormatException,
        );
        expect(
          () => RegistrationCompletionRequest(
            registrationId: id,
            pin: '12345',
          ).toJson(),
          throwsFormatException,
        );
      },
    );
  }
}
