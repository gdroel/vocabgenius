import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_screen.dart';
import '../notifications/notifications_service.dart';
import '../topics/topics_repository.dart';
import '../user_profile.dart';
import 'state.dart';
import 'theme.dart';
import 'screens/screens.dart';

const _kOnboardingStepKey = 'onboarding_step';
const _kOnboardingCompletedKey = 'onboarding_completed';

class OnboardingFlow extends StatefulWidget {
  final int initialStep;
  const OnboardingFlow({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _data = OnboardingData()..name = UserProfile.firstName;
  late final PageController _controller;
  late int _index;

  late final List<(String, Widget Function(StepCallbacks))> _steps = [
    ('Onboarding-01-Welcome', (cb) => Step01Welcome(cb: cb)),
    ('Onboarding-02-TailorIntro', (cb) => Step02TailorIntro(cb: cb)),
    ('Onboarding-04-Name', (cb) => Step04Name(cb: cb)),
    ('Onboarding-04b-WordOfDay', (cb) => Step04cWordOfDayNotification(cb: cb)),
    ('Onboarding-04c-LockscreenIntro', (cb) => Step04bLockscreenIntro(cb: cb)),
    ('Onboarding-11-Categories', (cb) => Step11Categories(cb: cb)),
    ('Onboarding-12-Curiosity', (cb) => Step12Curiosity(cb: cb)),
    ('Onboarding-13-VocabLevel', (cb) => Step13VocabLevel(cb: cb)),
    ('Onboarding-14-EncounterFreq', (cb) => Step14EncounterFreq(cb: cb)),
    ('Onboarding-15-SelfDescription', (cb) => Step15SelfDescription(cb: cb)),
    ('Onboarding-16-WeakSpots', (cb) => Step16WeakSpots(cb: cb)),
    ('Onboarding-17-BeginnerWords', (cb) => Step17BeginnerWords(cb: cb)),
    ('Onboarding-18-IntermediateWords', (cb) => Step18IntermediateWords(cb: cb)),
    ('Onboarding-19-AdvancedWords', (cb) => Step19AdvancedWords(cb: cb)),
    ('Onboarding-20-AssessmentReady', (cb) => Step20AssessmentReady(cb: cb)),
    ('Onboarding-21-BuildingPlan', (cb) => Step21BuildingPlan(cb: cb)),
    ('Onboarding-22-OneMinuteADay', (cb) => Step22OneMinuteADay(cb: cb)),
    ('Onboarding-23-ThreeDaysFree', (cb) => Step23ThreeDaysFree(cb: cb)),
    ('Onboarding-24-Trial', (cb) => Step24Trial(cb: cb)),
  ];

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_index < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skip() => _next();

  void _finish() {
    SharedPreferences.getInstance().then((p) {
      p.remove(_kOnboardingStepKey);
      p.setBool(_kOnboardingCompletedKey, true);
    }).catchError((_) {});
    // Kick off the daily 10am word-of-the-day notifications from the topics the
    // user just chose. (Delivers only if they granted notification permission.)
    NotificationsService.instance
        .scheduleWordOfDay(List.of(TopicsScope.of(context).followed))
        .catchError((_) {});
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: const RouteSettings(name: 'HomeScreen'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final start = widget.initialStep.clamp(0, _steps.length - 1);
    _index = start;
    _controller = PageController(initialPage: start);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackStep(start);
    });
  }

  void _persistStep(int i) {
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_kOnboardingStepKey, i))
        .catchError((_) => false);
  }

  void _trackStep(int i) {
    Posthog().screen(screenName: _steps[i].$1).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScope(
      data: _data,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: PageView.builder(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _steps.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            _persistStep(i);
            _trackStep(i);
          },
          itemBuilder: (_, i) => _steps[i].$2(
            StepCallbacks(
              next: _next,
              back: _back,
              skip: _skip,
              progress: (i + 1) / _steps.length,
              isFirst: i == 0,
              isLast: i == _steps.length - 1,
            ),
          ),
        ),
      ),
    );
  }
}

class StepCallbacks {
  final VoidCallback next;
  final VoidCallback back;
  final VoidCallback skip;
  final double progress;
  final bool isFirst;
  final bool isLast;
  const StepCallbacks({
    required this.next,
    required this.back,
    required this.skip,
    required this.progress,
    required this.isFirst,
    required this.isLast,
  });
}

