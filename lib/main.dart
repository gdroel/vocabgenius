import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'billing/billing_service.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_service.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';
import 'topics/topics_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = TopicsRepository();
  final billing = BillingService();
  await Future.wait([
    repo.load(),
    billing.init(),
    NotificationsService.instance.init(),
    Posthog().reloadFeatureFlags().catchError((_) {}),
  ]);
  runApp(ProfessorPipApp(topicsRepo: repo, billing: billing));
}

class ProfessorPipApp extends StatelessWidget {
  final TopicsRepository topicsRepo;
  final BillingService billing;
  const ProfessorPipApp({
    super.key,
    required this.topicsRepo,
    required this.billing,
  });

  @override
  Widget build(BuildContext context) {
    return TopicsScope(
      repo: topicsRepo,
      child: BillingScope(
        service: billing,
        child: MaterialApp(
          title: 'Professor Pip',
          debugShowCheckedModeBanner: false,
          theme: buildOnboardingTheme(),
          home: billing.isPro ? const HomeScreen() : const OnboardingFlow(),
        ),
      ),
    );
  }
}
