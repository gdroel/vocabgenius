import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'billing/billing_service.dart';
import 'bookmarks/bookmarks_repository.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_service.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';
import 'topics/topics_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = TopicsRepository();
  final billing = BillingService();
  final bookmarks = BookmarksRepository();
  await Future.wait([
    repo.load(),
    billing.init(),
    bookmarks.load(),
    NotificationsService.instance.init(),
    Posthog().reloadFeatureFlags().catchError((_) {}),
  ]);
  runApp(ProfessorPipApp(
    topicsRepo: repo,
    billing: billing,
    bookmarks: bookmarks,
  ));
}

class ProfessorPipApp extends StatelessWidget {
  final TopicsRepository topicsRepo;
  final BillingService billing;
  final BookmarksRepository bookmarks;
  const ProfessorPipApp({
    super.key,
    required this.topicsRepo,
    required this.billing,
    required this.bookmarks,
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
            home: billing.isPro ? const HomeScreen() : const OnboardingFlow(),
          ),
        ),
      ),
    );
  }
}
