import 'package:flutter_riverpod/flutter_riverpod.dart';

final recoveryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
