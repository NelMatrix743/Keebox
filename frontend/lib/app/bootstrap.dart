import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/config/environment_config.dart';

Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvironmentConfig.validate();
  runApp(ProviderScope(child: app));
}
