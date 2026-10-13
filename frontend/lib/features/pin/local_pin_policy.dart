abstract final class LocalPinPolicy {
  static const length = 5;
  static const maxAttempts = 5;
  static const recordVersion = 1;
  static const memoryKiB = 19 * 1024;
  static const iterations = 2;
  static const parallelism = 1;
  static const saltLength = 16;
  static const verifierLength = 32;

  static bool isValid(String pin) =>
      pin.length == length && RegExp(r'^[0-9]{5}$').hasMatch(pin);
}
