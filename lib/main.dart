import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'billing/billing_service.dart';
import 'billing/paywall_screen.dart';
import 'bookmarks/bookmarks_repository.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_service.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';
import 'push_service.dart';
import 'topics/topics_repository.dart';
import 'user_profile.dart';
import 'widget_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboardingStep = prefs.getInt('onboarding_step') ?? 0;
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  UserProfile.loadCached(prefs);
  WidgetPreferences.loadCached(prefs);
  final repo = TopicsRepository();
  final billing = BillingService()..loadCachedPro(prefs);
  final bookmarks = BookmarksRepository();

  // Only post-onboarding users need a verified entitlement to route
  // correctly on first paint. Onboarding users always go to the flow.
  await Future.wait([
    repo.load(),
    bookmarks.load(),
    NotificationsService.instance.init(),
    if (onboardingCompleted) billing.init(),
  ]);

  runApp(ProfessorPipApp(
    topicsRepo: repo,
    billing: billing,
    bookmarks: bookmarks,
    onboardingStep: onboardingStep,
    onboardingCompleted: onboardingCompleted,
  ));

  if (!onboardingCompleted) {
    billing.init();
  } else {
    // Refresh the rolling 10am word-of-the-day window from current topics.
    NotificationsService.instance
        .scheduleWordOfDay(repo.followed)
        .catchError((_) {});
  }
  PushService.instance.init();
  Posthog().reloadFeatureFlags().catchError((_) {});
}

class ProfessorPipApp extends StatelessWidget {
  final TopicsRepository topicsRepo;
  final BillingService billing;
  final BookmarksRepository bookmarks;
  final int onboardingStep;
  final bool onboardingCompleted;
  const ProfessorPipApp({
    super.key,
    required this.topicsRepo,
    required this.billing,
    required this.bookmarks,
    required this.onboardingStep,
    required this.onboardingCompleted,
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
            navigatorKey: PushService.navigatorKey,
            navigatorObservers: [PosthogObserver()],
            home: ListenableBuilder(
              listenable: billing,
              builder: (_, _) {
                if (!onboardingCompleted) {
                  return OnboardingFlow(initialStep: onboardingStep);
                }
                if (billing.isPro) return const HomeScreen();
                return _PaywallGate();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PaywallGate extends StatefulWidget {
  @override
  State<_PaywallGate> createState() => _PaywallGateState();
}

class _PaywallGateState extends State<_PaywallGate> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const HomeScreen();
    return PaywallScreen(
      onDismiss: () => setState(() => _dismissed = true),
      onPurchased: () {},
    );
  }
}
