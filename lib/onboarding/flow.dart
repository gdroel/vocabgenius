import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'screens/screens.dart';

const _kOnboardingStepKey = 'onboarding_step';

class OnboardingFlow extends StatefulWidget {
  final int initialStep;
  const OnboardingFlow({super.key, this.initialStep = 0});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _data = OnboardingData();
  late final PageController _controller;
  late int _index;

  late final List<Widget Function(StepCallbacks)> _builders = [
    (cb) => Step01Welcome(cb: cb),
    (cb) => Step02TailorIntro(cb: cb),
    (cb) => Step03Gender(cb: cb),
    (cb) => Step04Name(cb: cb),
    (cb) => Step05CustomizeIntro(cb: cb),
    (cb) => Step11Categories(cb: cb),
    (cb) => Step12Curiosity(cb: cb),
    (cb) => Step13VocabLevel(cb: cb),
    (cb) => Step14EncounterFreq(cb: cb),
    (cb) => Step15SelfDescription(cb: cb),
    (cb) => Step16WeakSpots(cb: cb),
    (cb) => Step17BeginnerWords(cb: cb),
    (cb) => Step18IntermediateWords(cb: cb),
    (cb) => Step19AdvancedWords(cb: cb),
    (cb) => Step20AssessmentReady(cb: cb),
    (cb) => Step21BuildingPlan(cb: cb),
    (cb) => Step22OneMinuteADay(cb: cb),
    (cb) => Step23ThreeDaysFree(cb: cb),
    (cb) => Step24Trial(cb: cb),
  ];

  void _next() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_index < _builders.length - 1) {
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
    SharedPreferences.getInstance()
        .then((p) => p.remove(_kOnboardingStepKey))
        .catchError((_) => false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    final start = widget.initialStep.clamp(0, _builders.length - 1);
    _index = start;
    _controller = PageController(initialPage: start);
  }

  void _persistStep(int i) {
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_kOnboardingStepKey, i))
        .catchError((_) => false);
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
          itemCount: _builders.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            _persistStep(i);
          },
          itemBuilder: (_, i) => _builders[i](
            StepCallbacks(
              next: _next,
              back: _back,
              skip: _skip,
              progress: (i + 1) / _builders.length,
              isFirst: i == 0,
              isLast: i == _builders.length - 1,
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

