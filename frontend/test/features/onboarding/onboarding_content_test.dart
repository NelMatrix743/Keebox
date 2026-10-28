import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_content.dart';

void main() {
  for (final step in OnboardingStep.values) {
    testWidgets('${step.name} shows its own illustration and message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(402, 874),
          builder: (_, child) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 352,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OnboardingArtwork(step: step),
                      OnboardingMessage(step: step),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, step.illustration);
      await tester.runAsync(
        () => precacheImage(image.image, tester.element(find.byType(Image))),
      );
      await tester.pump();
      expect(find.text(step.title), findsOneWidget);
      expect(find.text(step.description), findsOneWidget);
      final title = tester.widget<Text>(find.text(step.title));
      expect(
        title.textAlign,
        step == OnboardingStep.welcome ? TextAlign.center : TextAlign.left,
      );
      expect(
        tester.getSize(find.byType(OnboardingArtwork)),
        const Size(352, 440),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
