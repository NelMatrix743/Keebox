import 'package:flutter/material.dart';

class AuthenticatedPlaceholderScreen extends StatelessWidget {
  const AuthenticatedPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Keebox'),
      automaticallyImplyLeading: false,
    ),
    body: const SafeArea(child: Center(child: Text('You are signed in.'))),
  );
}
