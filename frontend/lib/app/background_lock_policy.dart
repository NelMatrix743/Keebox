import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class BackgroundLockPolicy {
  static const gracePeriod = Duration(seconds: 20);
}

final backgroundTimerProvider =
    Provider<Timer Function(Duration, void Function())>((ref) => Timer.new);

final backgroundElapsedProvider = Provider<Duration Function()>((ref) {
  final clock = Stopwatch()..start();
  ref.onDispose(clock.stop);
  return () => clock.elapsed;
});
