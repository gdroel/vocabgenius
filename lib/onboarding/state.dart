import 'package:flutter/material.dart';

class OnboardingData extends ChangeNotifier {
  String? gender;
  String name = '';
  bool dailyRoutine = true;
  bool notificationsEnabled = true;
  int notificationsPerDay = 10;
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 22, minute: 0);
  String theme = 'light';
  Set<String> topics = {};
  Set<String> categories = {};
  String? curiosity;
  String? vocabularyLevel;
  String? encounterFrequency;
  String? selfDescription;
  Set<String> weakSpots = {};
  Set<String> beginnerKnown = {};
  Set<String> intermediateKnown = {};
  Set<String> advancedKnown = {};
  bool reminderBeforeTrialEnds = true;

  void update(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}

class OnboardingScope extends InheritedNotifier<OnboardingData> {
  const OnboardingScope({
    super.key,
    required OnboardingData data,
    required super.child,
  }) : super(notifier: data);

  static OnboardingData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OnboardingScope>();
    assert(scope != null, 'OnboardingScope missing');
    return scope!.notifier!;
  }
}
