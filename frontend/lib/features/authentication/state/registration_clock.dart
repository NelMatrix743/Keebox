import 'package:flutter_riverpod/flutter_riverpod.dart';

final registrationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
