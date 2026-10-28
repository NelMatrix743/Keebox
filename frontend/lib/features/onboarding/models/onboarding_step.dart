import 'package:keebox/app/app_texts.dart';
import 'package:keebox/assets/app_assets.dart';

enum OnboardingStep {
  notes(
    illustration: AppAssets.onboardingNotes,
    title: AppTexts.onboardingNotesTitle,
    description: AppTexts.onboardingNotesDescription,
  ),
  credentials(
    illustration: AppAssets.onboardingCredentials,
    title: AppTexts.onboardingCredentialsTitle,
    description: AppTexts.onboardingCredentialsDescription,
  ),
  privacy(
    illustration: AppAssets.onboardingPrivacy,
    title: AppTexts.onboardingPrivacyTitle,
    description: AppTexts.onboardingPrivacyDescription,
  ),
  backup(
    illustration: AppAssets.onboardingBackup,
    title: AppTexts.onboardingBackupTitle,
    description: AppTexts.onboardingBackupDescription,
  ),
  welcome(
    illustration: AppAssets.onboardingWelcome,
    title: AppTexts.onboardingWelcomeTitle,
    description: AppTexts.onboardingWelcomeDescription,
  );

  const OnboardingStep({
    required this.illustration,
    required this.title,
    required this.description,
  });

  final String illustration;
  final String title;
  final String description;
}
