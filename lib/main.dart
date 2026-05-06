import 'package:flutter/material.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';
import 'topics/topics_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = TopicsRepository();
  await repo.load();
  runApp(ProfessorPipApp(topicsRepo: repo));
}

class ProfessorPipApp extends StatelessWidget {
  final TopicsRepository topicsRepo;
  const ProfessorPipApp({super.key, required this.topicsRepo});

  @override
  Widget build(BuildContext context) {
    return TopicsScope(
      repo: topicsRepo,
      child: MaterialApp(
        title: 'Professor Pip',
        debugShowCheckedModeBanner: false,
        theme: buildOnboardingTheme(),
        home: const OnboardingFlow(),
      ),
    );
  }
}
