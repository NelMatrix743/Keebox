import 'package:flutter/material.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({required this.user, super.key});
  final AuthenticatedUser user;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in [
            (AppTexts.userId, user.id),
            (AppTexts.firstName, user.firstName),
            (AppTexts.lastName, user.lastName),
            (AppTexts.email, user.email),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.$1,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  SelectableText(
                    field.$2,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
