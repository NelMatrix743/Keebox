import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';

class AuthenticationLifecycle extends ConsumerStatefulWidget {
  const AuthenticationLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AuthenticationLifecycle> createState() =>
      _AuthenticationLifecycleState();
}

class _AuthenticationLifecycleState
    extends ConsumerState<AuthenticationLifecycle>
    with WidgetsBindingObserver {
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    ref
        .read(authenticationControllerProvider.notifier)
        .setApplicationActive(active);
    if (mounted) setState(() => _active = active);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (!_active)
        const Positioned.fill(child: ColoredBox(color: Colors.white)),
    ],
  );
}
