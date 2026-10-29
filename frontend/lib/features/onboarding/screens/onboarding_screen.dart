import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/state/onboarding_controller.dart';
import 'package:keebox/features/onboarding/state/onboarding_state.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_buttons.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_content.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_decoration.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    required this.onSignIn,
    required this.onGetStarted,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pages;
  bool _departing = false;

  @override
  void initState() {
    super.initState();
    _pages = PageController(
      initialPage:
          ref.read(onboardingControllerProvider).asData?.value.step.index ?? 0,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _syncPage() {
    if (!mounted) return;
    if (!_pages.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPage());
      return;
    }
    final index =
        ref.read(onboardingControllerProvider).asData?.value.step.index ?? 0;
    if (_pages.page?.round() != index) _pages.jumpToPage(index);
  }

  Future<void> _complete(VoidCallback navigate) async {
    if (!mounted || _departing) return;
    setState(() => _departing = true);
    AppSnackBar.dismiss(context);
    final completed = await ref
        .read(onboardingControllerProvider.notifier)
        .complete();
    if (!mounted) return;
    if (!completed || ModalRoute.of(context)?.isCurrent == false) {
      setState(() => _departing = false);
      return;
    }
    navigate();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(onboardingControllerProvider);
    final current = progress.asData?.value ?? const OnboardingState();
    final controller = ref.read(onboardingControllerProvider.notifier);
    final busy = _departing || progress.isLoading || current.isSaving;
    ref.listen(onboardingControllerProvider, (previous, next) {
      if (previous?.asData?.value.step != next.asData?.value.step) _syncPage();
      final message = next.asData?.value.errorMessage;
      if (message != null && message != previous?.asData?.value.errorMessage) {
        AppSnackBar.show(
          context,
          message: message,
          type: AppSnackBarType.error,
        );
      }
    });
    return PopScope(
      canPop: !busy && current.step == OnboardingStep.notes,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) controller.previous();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemUiOverlayStyle,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.max(0.0, constraints.maxWidth - 50.w);
                      final messageHeight = OnboardingStep.values
                          .take(OnboardingStep.welcome.index)
                          .map(
                            (step) =>
                                OnboardingMessage(step: step)
                                    .measureHeight(context, width),
                          )
                          .reduce(math.max);
                      final headerHeight = math.max(48.0, 87.h);
                      final stripGap = current.isWelcome ? 0.0 : 34.h;
                      return Column(
                        children: [
                          SizedBox(
                            height: headerHeight,
                            child: current.isWelcome
                                ? null
                                : Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: math.min(
                                          23.5.h,
                                          math.max(0.0, headerHeight - 48),
                                        ),
                                        right: 24.w,
                                      ),
                                      child: OnboardingSkipButton(
                                        onPressed: busy
                                            ? null
                                            : controller.skip,
                                      ),
                                    ),
                                  ),
                          ),
                          Expanded(
                            child: PageView.builder(
                              controller: _pages,
                              physics: busy || current.isCompleted
                                  ? const NeverScrollableScrollPhysics()
                                  : const PageScrollPhysics(),
                              onPageChanged: controller.setPage,
                              itemCount: OnboardingStep.values.length,
                              itemBuilder: (context, index) => Padding(
                                padding: EdgeInsets.symmetric(horizontal: 25.w),
                                child: _OnboardingPageContent(
                                  step: OnboardingStep.values[index],
                                  introductionMessageHeight: messageHeight,
                                ),
                              ),
                            ),
                          ),
                          if (!current.isWelcome) ...[
                            SizedBox(height: stripGap),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: OnboardingDecorativeStrip(),
                            ),
                            SizedBox(height: 16.h),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: current.isWelcome
                      ? EdgeInsets.fromLTRB(14.w, 0, 19.w, 39.h)
                      : EdgeInsets.fromLTRB(30.w, 0, 24.w, 36.h),
                  child: current.isWelcome
                      ? OnboardingWelcomeActions(
                          onSignIn: busy
                              ? null
                              : () => _complete(widget.onSignIn),
                          onGetStarted: busy
                              ? null
                              : () => _complete(widget.onGetStarted),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 7.h),
                              child: OnboardingProgressIndicators(
                                step: current.step,
                              ),
                            ),
                            OnboardingNextButton(
                              onPressed: busy ? null : controller.next,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  const _OnboardingPageContent({
    required this.step,
    required this.introductionMessageHeight,
  });
  final OnboardingStep step;
  final double introductionMessageHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final message = OnboardingMessage(step: step);
      final messageHeight = message.measureHeight(
        context,
        constraints.maxWidth,
      );
      final reservedText = step == OnboardingStep.welcome
          ? messageHeight
          : introductionMessageHeight;
      final gap = step == OnboardingStep.welcome ? 0.0 : 28.h;
      final artworkHeight = math.min(
        constraints.maxWidth * 440 / 352,
        math.max(0.0, constraints.maxHeight - reservedText - gap),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (artworkHeight > 0) ...[
            Center(
              child: SizedBox(
                width: artworkHeight * 352 / 440,
                height: artworkHeight,
                child: OnboardingArtwork(step: step),
              ),
            ),
            SizedBox(height: gap),
          ],
          SizedBox(
            height: math.min(messageHeight, constraints.maxHeight),
            child: FittedBox(
              alignment: step == OnboardingStep.welcome
                  ? Alignment.topCenter
                  : Alignment.topLeft,
              fit: BoxFit.scaleDown,
              child: SizedBox(width: constraints.maxWidth, child: message),
            ),
          ),
        ],
      );
    },
  );
}
