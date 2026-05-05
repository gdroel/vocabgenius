import 'package:flutter/material.dart';
import 'onboarding/flow.dart';
import 'onboarding/theme.dart';

void main() {
  runApp(const VocabGeniusApp());
}

class VocabGeniusApp extends StatelessWidget {
  const VocabGeniusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: buildOnboardingTheme(),
      home: const OnboardingFlow(),
    );
  }
}
