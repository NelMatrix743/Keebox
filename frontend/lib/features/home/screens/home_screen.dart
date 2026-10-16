import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/home/widgets/user_profile_card.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(afterLogin: true);
    });
  }

  Future<void> _refresh({bool afterLogin = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final controller = ref.read(authenticationControllerProvider.notifier);
      if (afterLogin) {
        await controller.fetchProfileAfterLogin();
      } else {
        await controller.refreshCurrentUser();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: AppTexts.profileUnavailable,
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authenticationControllerProvider.notifier).signOut();
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          AppSnackBar(
            message: AppTexts.logoutLocalOnly,
            type: AppSnackBarType.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authenticationControllerProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.home),
        actions: [
          IconButton(
            tooltip: AppTexts.logout,
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  AppTexts.homePlaceholder,
                  textAlign: TextAlign.center,
                ),
                if (auth is AuthenticatedUnlocked)
                  UserProfileCard(user: auth.user),
                if (_loading)
                  const CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: _refresh,
                    child: const Text(AppTexts.refreshProfile),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
