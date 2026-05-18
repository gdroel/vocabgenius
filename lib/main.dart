import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'billing/billing_service.dart';
import 'bookmarks/bookmarks_repository.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_service.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';
import 'topics/topics_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingStep = prefs.getInt('onboarding_step') ?? 0;

  final repo = TopicsRepository();
  final billing = BillingService()..loadCachedPro(prefs);
  final bookmarks = BookmarksRepository();

  await Future.wait([
    repo.load(),
    bookmarks.load(),
    NotificationsService.instance.init(),
  ]);

  runApp(ProfessorPipApp(
    topicsRepo: repo,
    billing: billing,
    bookmarks: bookmarks,
    onboardingStep: onboardingStep,
  ));

  // Background work that shouldn't block first paint.
  billing.init();
  Posthog().reloadFeatureFlags().catchError((_) {});
}

class ProfessorPipApp extends StatelessWidget {
  final TopicsRepository topicsRepo;
  final BillingService billing;
  final BookmarksRepository bookmarks;
  final int onboardingStep;
  const ProfessorPipApp({
    super.key,
    required this.topicsRepo,
    required this.billing,
    required this.bookmarks,
    required this.onboardingStep,
  });

  @override
  Widget build(BuildContext context) {
    return TopicsScope(
      repo: topicsRepo,
      child: BillingScope(
        service: billing,
        child: BookmarksScope(
          repo: bookmarks,
          child: MaterialApp(
            title: 'Professor Pip',
            debugShowCheckedModeBanner: false,
            theme: buildOnboardingTheme(),
            navigatorObservers: [PosthogObserver()],
            home: ListenableBuilder(
              listenable: billing,
              builder: (_, _) => billing.isPro
                  ? const HomeScreen()
                  : OnboardingFlow(initialStep: onboardingStep),
            ),
          ),
        ),
      ),
    );
  }
}
