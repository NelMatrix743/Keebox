import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';
import 'package:keebox/app/startup/startup_gate.dart';
import 'package:keebox/config/environment_config.dart';

Future<void> bootstrap(Widget app) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  EnvironmentConfig.validate();
  final container = ProviderContainer(
    overrides: [
      initialRouteProvider.overrideWith(
        (ref) => ref.read(startupCoordinatorProvider).requireValue,
      ),
    ],
  );
  try {
    await container.read(startupCoordinatorProvider.future);
  } catch (_) {
    // The gate presents retry controls without discarding stored credentials.
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: StartupGate(child: app),
    ),
  );
}
