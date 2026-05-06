import 'package:flutter/material.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';
import 'topics/topics_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = TopicsRepository();
  await repo.load();
  runApp(VocabGeniusApp(topicsRepo: repo));
}

class VocabGeniusApp extends StatelessWidget {
  final TopicsRepository topicsRepo;
  const VocabGeniusApp({super.key, required this.topicsRepo});

  @override
  Widget build(BuildContext context) {
    return TopicsScope(
      repo: topicsRepo,
      child: MaterialApp(
        title: 'Vocabulary',
        debugShowCheckedModeBanner: false,
        theme: buildOnboardingTheme(),
        home: const OnboardingFlow(),
      ),
    );
  }
}
