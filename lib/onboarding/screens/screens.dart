import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';
import '../../billing/paywall_screen.dart';
import '../../topics/topics_catalog.dart';
import '../../topics/topics_repository.dart';
import '../flow.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// Reusable layout: hero illustration + title + continue button
class _IntroScreen extends StatelessWidget {
  final StepCallbacks cb;
  final IconData icon;
  final String title;
  final String? subtitle;
  const _IntroScreen({
    required this.cb,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      showBack: !cb.isFirst,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    HeroIllustration(icon: icon, size: 170),
                    const SizedBox(height: 32),
                    TitleHeader(title: title, subtitle: subtitle),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            PrimaryButton(label: 'Continue', onPressed: cb.next),
          ],
        ),
      ),
    );
  }
}

class _SingleChoiceScreen extends StatefulWidget {
  final StepCallbacks cb;
  final String title;
  final String? subtitle;
  final List<String> options;
  final String? Function(OnboardingData) read;
  final void Function(OnboardingData, String) write;
  const _SingleChoiceScreen({
    required this.cb,
    required this.title,
    this.subtitle,
    required this.options,
    required this.read,
    required this.write,
  });

  @override
  State<_SingleChoiceScreen> createState() => _SingleChoiceScreenState();
}

class _SingleChoiceScreenState extends State<_SingleChoiceScreen> {
  @override
  Widget build(BuildContext context) {
    final data = OnboardingScope.of(context);
    final selected = widget.read(data);
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      onSkip: widget.cb.skip,
      showSkip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            TitleHeader(title: widget.title, subtitle: widget.subtitle),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final opt = widget.options[i];
                  return OptionTile(
                    label: opt,
                    selected: selected == opt,
                    onTap: () => data.update(() => widget.write(data, opt)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Continue',
              onPressed: selected == null ? null : widget.cb.next,
              enabled: selected != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiChoiceScreen extends StatefulWidget {
  final StepCallbacks cb;
  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> Function(OnboardingData) read;
  final bool showSkip;
  const _MultiChoiceScreen({
    required this.cb,
    required this.title,
    this.subtitle,
    required this.options,
    required this.read,
    this.showSkip = true,
  });

  @override
  State<_MultiChoiceScreen> createState() => _MultiChoiceScreenState();
}

class _MultiChoiceScreenState extends State<_MultiChoiceScreen> {
  @override
  Widget build(BuildContext context) {
    final data = OnboardingScope.of(context);
    final set = widget.read(data);
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      onSkip: widget.cb.skip,
      showSkip: widget.showSkip,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            TitleHeader(title: widget.title, subtitle: widget.subtitle),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: widget.options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final opt = widget.options[i];
                  return OptionTile(
                    label: opt,
                    selected: set.contains(opt),
                    onTap: () => data.update(() {
                      set.contains(opt) ? set.remove(opt) : set.add(opt);
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Continue',
              onPressed: set.isEmpty ? null : widget.cb.next,
              enabled: set.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }
}

// 1. Welcome / landing
class Step01Welcome extends StatelessWidget {
  final StepCallbacks cb;
  const Step01Welcome({super.key, required this.cb});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              const _PipIntroBubble(
                lines: [
                  "Hey! I'm Professor Pip.",
                  "Stick me on your lock screen and you'll learn new vocabulary every time you glance at your phone.",
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Brutal.borderColor,
                    width: Brutal.borderWidth,
                  ),
                  boxShadow: Brutal.shadow(dx: 4, dy: 6),
                ),
                clipBehavior: Clip.antiAlias,
                child: Transform.scale(
                  scale: 1.25,
                  child: Image.asset(
                    'assets/hero-image.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              PrimaryButton(label: 'Nice to meet you, Pip', onPressed: cb.next),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipIntroBubble extends StatefulWidget {
  final List<String> lines;
  const _PipIntroBubble({required this.lines});

  @override
  State<_PipIntroBubble> createState() => _PipIntroBubbleState();
}

class _PipIntroBubbleState extends State<_PipIntroBubble>
    with SingleTickerProviderStateMixin {
  late final String _full = widget.lines.join('\n\n');
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_full.length * 22).clamp(900, 3200)),
  );
  late final Animation<int> _chars = StepTween(begin: 0, end: _full.length)
      .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut));

  int _lastTickedAt = 0;

  @override
  void initState() {
    super.initState();
    _chars.addListener(() {
      final shown = _chars.value;
      if (shown > _lastTickedAt && shown - _lastTickedAt >= 3) {
        _lastTickedAt = shown;
        HapticFeedback.selectionClick();
      }
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 4, dy: 5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Professor Pip',
            style: TextStyle(
              color: AppColors.burgundy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _chars,
            builder: (_, _) {
              final shown = _full.substring(0, _chars.value);
              final isTyping = _chars.value < _full.length;
              return RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: shown),
                    if (isTyping)
                      const TextSpan(
                        text: '▍',
                        style: TextStyle(color: AppColors.muted),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


// 2. Tailor word recommendations
class Step02TailorIntro extends StatelessWidget {
  final StepCallbacks cb;
  const Step02TailorIntro({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _IntroScreen(
    cb: cb,
    icon: Icons.stairs_rounded,
    title: 'Tailor your word\nrecommendations',
  );
}

// 3. Gender
class Step03Gender extends StatelessWidget {
  final StepCallbacks cb;
  const Step03Gender({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _SingleChoiceScreen(
    cb: cb,
    title: 'Which option represents\nyou best?',
    options: const ['Female', 'Male', 'Other', 'Prefer not to say'],
    read: (d) => d.gender,
    write: (d, v) => d.gender = v,
  );
}

// 4. Name
class Step04Name extends StatefulWidget {
  final StepCallbacks cb;
  const Step04Name({super.key, required this.cb});
  @override
  State<Step04Name> createState() => _Step04NameState();
}

class _Step04NameState extends State<Step04Name> {
  late final TextEditingController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = OnboardingScope.of(context);
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      onSkip: widget.cb.skip,
      showSkip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const TitleHeader(title: 'What do you want to\nbe called?'),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: Brutal.shadow(dx: 4, dy: 5),
              ),
              child: TextField(
                controller: _ctl,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                onChanged: (v) => data.update(() => data.name = v),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: const TextStyle(color: AppColors.muted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 22,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(36),
                    borderSide: BorderSide(
                      color: Brutal.borderColor,
                      width: Brutal.borderWidth,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(36),
                    borderSide: BorderSide(
                      color: Brutal.borderColor,
                      width: Brutal.borderWidth,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(36),
                    borderSide: BorderSide(
                      color: Brutal.borderColor,
                      width: Brutal.borderWidth,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Continue',
              onPressed: data.name.trim().isEmpty ? null : widget.cb.next,
              enabled: data.name.trim().isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }
}

// 5. Customize app intro
class Step05CustomizeIntro extends StatelessWidget {
  final StepCallbacks cb;
  const Step05CustomizeIntro({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _IntroScreen(
    cb: cb,
    icon: Icons.tune_rounded,
    title: 'Customize the app to\nimprove your experience',
  );
}

// 6. Daily routine streak
class Step06DailyRoutine extends StatelessWidget {
  final StepCallbacks cb;
  const Step06DailyRoutine({super.key, required this.cb});
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.creamSoft,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Brutal.borderColor,
                      width: Brutal.borderWidth,
                    ),
                    boxShadow: Brutal.shadow(dx: 5, dy: 7),
                  ),
                ),
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 90,
                  color: AppColors.flame,
                ),
                const Positioned(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const TitleHeader(
              title: 'Create a consistent daily\nlearning routine',
            ),
            const SizedBox(height: 24),
            const _StreakRow(),
            const Spacer(),
            PrimaryButton(label: 'Continue', onPressed: cb.next),
          ],
        ),
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 4, dy: 5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final active = i == 0;
              return Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.teal
                      : AppColors.creamSoft,
                  border: Border.all(
                    color: Brutal.borderColor,
                    width: Brutal.borderWidth,
                  ),
                ),
                alignment: Alignment.center,
                child: active
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              );
            }),
          ),
          const SizedBox(height: 10),
          const Text(
            'Build a streak, one day at a time',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// 7. Notifications
class Step07Notifications extends StatelessWidget {
  final StepCallbacks cb;
  const Step07Notifications({super.key, required this.cb});

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final data = OnboardingScope.of(context);
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const TitleHeader(
              title: 'Get words throughout\nthe day',
              subtitle: 'Allow notifications to get daily words',
            ),
            const SizedBox(height: 24),
            _NotifPreview(),
            const SizedBox(height: 14),
            _NotifControl(
              label: 'How many',
              child: _Stepper(
                value: data.notificationsPerDay,
                min: 1,
                max: 30,
                onChanged: (v) => data.update(
                  () => data.notificationsPerDay = v,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _NotifControl(
              label: 'Start at',
              onTap: () => _pickTime(
                context,
                data.startTime,
                (t) => data.update(() => data.startTime = t),
              ),
              child: Text(_fmt(data.startTime)),
            ),
            const SizedBox(height: 12),
            _NotifControl(
              label: 'End at',
              onTap: () => _pickTime(
                context,
                data.endTime,
                (t) => data.update(() => data.endTime = t),
              ),
              child: Text(_fmt(data.endTime)),
            ),
            const Spacer(),
            PrimaryButton(label: 'Allow and Save', onPressed: cb.next),
          ],
        ),
      ),
    );
  }
}

class _NotifPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 4, dy: 5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Brutal.borderColor,
                width: Brutal.borderWidth,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.menu_book,
              size: 20,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Professor Pip',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                SizedBox(height: 2),
                Text(
                  'Salubrious (adj.) – clean,\nconducive to health',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifControl extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  const _NotifControl({required this.label, required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 3, dy: 5),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            DefaultTextStyle(
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          i,
          size: 20,
          color: onTap == null
              ? AppColors.muted.withValues(alpha: 0.4)
              : AppColors.ink,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 64,
          child: Text(
            '${value}x',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

// 8. Theme
class Step08Theme extends StatelessWidget {
  final StepCallbacks cb;
  const Step08Theme({super.key, required this.cb});

  @override
  Widget build(BuildContext context) {
    final data = OnboardingScope.of(context);
    final themes = const [
      ('light', Colors.white, AppColors.ink),
      ('sepia', Color(0xFFE9D8A6), AppColors.ink),
      ('dark', Color(0xFF1F1F1F), Colors.white),
      ('forest', Color(0xFF2A3D2A), Colors.white),
    ];
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const TitleHeader(title: 'Which theme would\nyou like to start with?'),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.7,
                children: [
                  for (final t in themes)
                    GestureDetector(
                      onTap: () => data.update(() => data.theme = t.$1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.$2,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: data.theme == t.$1
                                ? AppColors.teal
                                : Brutal.borderColor,
                            width: data.theme == t.$1 ? 4 : Brutal.borderWidth,
                          ),
                          boxShadow: Brutal.shadow(dx: 4, dy: 5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Aa',
                          style: TextStyle(
                            color: t.$3,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Continue', onPressed: cb.next),
          ],
        ),
      ),
    );
  }
}

// 9. Goals intro
class Step09GoalsIntro extends StatelessWidget {
  final StepCallbacks cb;
  const Step09GoalsIntro({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _IntroScreen(
    cb: cb,
    icon: Icons.auto_stories_rounded,
    title: 'Set up Professor Pip to help\nyou achieve your goals',
  );
}

// 10. Topics
class Step10Topics extends StatelessWidget {
  final StepCallbacks cb;
  const Step10Topics({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    title: 'Which topics are you\ninterested in?',
    options: const [
      'Society',
      'Emotions',
      'Business',
      'Human body',
      'Words in foreign languages',
      'Other',
    ],
    read: (d) => d.topics,
  );
}

// 11. Categories (chips) — backed by TopicsRepository
class Step11Categories extends StatefulWidget {
  final StepCallbacks cb;
  const Step11Categories({super.key, required this.cb});
  @override
  State<Step11Categories> createState() => _Step11CategoriesState();
}

class _Step11CategoriesState extends State<Step11Categories> {
  @override
  Widget build(BuildContext context) {
    final repo = TopicsScope.of(context);
    final selected = repo.followed;
    const minTopics = 3;
    final remaining = minTopics - selected.length;
    final hasEnough = remaining <= 0;
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            TitleHeader(
              title: 'Which topics are you\ninterested in?',
              subtitle: hasEnough
                  ? "Nice. You can change these any time."
                  : 'Pick at least $minTopics to keep going',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: TopicsCatalog.all
                      .map(
                        (t) => Chip(
                          label: t.title,
                          selected: selected.contains(t.id),
                          onTap: () async {
                            await repo.toggle(t.id);
                            if (mounted) setState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: hasEnough
                  ? 'Continue'
                  : 'Pick $remaining more',
              onPressed: hasEnough ? widget.cb.next : null,
              enabled: hasEnough,
            ),
          ],
        ),
      ),
    );
  }
}

// 12. Curiosity
class Step12Curiosity extends StatelessWidget {
  final StepCallbacks cb;
  const Step12Curiosity({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _SingleChoiceScreen(
    cb: cb,
    title: 'What drives your curiosity?',
    subtitle: 'Select at least one option to continue',
    options: const [
      "I'm a lifelong learner",
      'Knowing more than others',
      'Impressing other people',
      'Breaking out of my bubble',
      'Other',
    ],
    read: (d) => d.curiosity,
    write: (d, v) => d.curiosity = v,
  );
}

// 13. Vocab level
class Step13VocabLevel extends StatelessWidget {
  final StepCallbacks cb;
  const Step13VocabLevel({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _SingleChoiceScreen(
    cb: cb,
    title: "What's your\nvocabulary level?",
    subtitle: 'Select an option to continue',
    options: const ['Beginner', 'Intermediate', 'Advanced'],
    read: (d) => d.vocabularyLevel,
    write: (d, v) => d.vocabularyLevel = v,
  );
}

// 14. Encounter unknown words
class Step14EncounterFreq extends StatelessWidget {
  final StepCallbacks cb;
  const Step14EncounterFreq({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _SingleChoiceScreen(
    cb: cb,
    title: "Do you often encounter\nwords you don't know?",
    options: const ['Daily', 'A few times a week', 'Rarely', 'Never'],
    read: (d) => d.encounterFrequency,
    write: (d, v) => d.encounterFrequency = v,
  );
}

// 15. Self description
class Step15SelfDescription extends StatelessWidget {
  final StepCallbacks cb;
  const Step15SelfDescription({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _SingleChoiceScreen(
    cb: cb,
    title: 'How would you describe\nyour vocabulary?',
    options: const [
      'Struggle to find the right words',
      'Get by but want to improve',
      'Comfortable in most situations',
      'Very articulate',
    ],
    read: (d) => d.selfDescription,
    write: (d, v) => d.selfDescription = v,
  );
}

// 16. Where weakest
class Step16WeakSpots extends StatelessWidget {
  final StepCallbacks cb;
  const Step16WeakSpots({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    title: 'Where does your vocabulary\nfeel weakest?',
    options: const [
      'At work',
      'I always feel confident',
      'When reading',
      'In social conversations',
      'When writing',
      'In school',
    ],
    read: (d) => d.weakSpots,
  );
}

// 17. Beginner words
class Step17BeginnerWords extends StatelessWidget {
  final StepCallbacks cb;
  const Step17BeginnerWords({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    title: 'Beginner words',
    subtitle: 'Select all the ones you know',
    options: const [
      'Eager',
      'Vivid',
      'Brisk',
      'Hollow',
      'Mellow',
      'Dwindle',
    ],
    read: (d) => d.beginnerKnown,
    showSkip: false,
  );
}

// 18. Intermediate words
class Step18IntermediateWords extends StatelessWidget {
  final StepCallbacks cb;
  const Step18IntermediateWords({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    title: 'Intermediate words',
    subtitle: 'Select all the ones you know',
    options: const [
      'Ephemeral',
      'Candid',
      'Astute',
      'Beguile',
      'Tacit',
      'Wistful',
    ],
    read: (d) => d.intermediateKnown,
    showSkip: false,
  );
}

// 19. Advanced words
class Step19AdvancedWords extends StatelessWidget {
  final StepCallbacks cb;
  const Step19AdvancedWords({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    title: 'Advanced words',
    subtitle: 'Select all the ones you know',
    options: const [
      'Petrichor',
      'Sonder',
      'Sesquipedalian',
      'Susurrus',
      'Apricity',
      'Defenestrate',
    ],
    read: (d) => d.advancedKnown,
    showSkip: false,
  );
}

// 20. Assessment ready
class Step20AssessmentReady extends StatelessWidget {
  final StepCallbacks cb;
  const Step20AssessmentReady({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _IntroScreen(
    cb: cb,
    icon: Icons.assignment_turned_in_rounded,
    title: 'Great!',
    subtitle:
        'A personalized level assessment is waiting for you in the app',
  );
}

// 21. Building plan (loading) — added to make it 24 steps
class Step21BuildingPlan extends StatefulWidget {
  final StepCallbacks cb;
  const Step21BuildingPlan({super.key, required this.cb});
  @override
  State<Step21BuildingPlan> createState() => _Step21BuildingPlanState();
}

class _Step21BuildingPlanState extends State<Step21BuildingPlan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _ac.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) widget.cb.next();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Image.asset(
              'assets/personalizedplan.png',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            const TitleHeader(
              title: 'Building your\npersonalized plan',
              subtitle: 'This will only take a moment...',
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _ac,
              builder: (_, _) => ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: _ac.value,
                  minHeight: 6,
                  backgroundColor: AppColors.creamSoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// 22. Become more articulate — Pip pitch
class Step22OneMinuteADay extends StatelessWidget {
  final StepCallbacks cb;
  const Step22OneMinuteADay({super.key, required this.cb});
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 1),
            const _PipIntroBubble(
              lines: [
                "You'll become more articulate in just 1 minute a day, without even opening the app.",
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 4, dy: 6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Transform.scale(
                scale: 1.25,
                child: Image.asset(
                  'assets/hero-image.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Spacer(flex: 2),
            PrimaryButton(label: 'Continue', onPressed: cb.next),
          ],
        ),
      ),
    );
  }
}

// 23. Three days free — Pip pitch
class Step23ThreeDaysFree extends StatelessWidget {
  final StepCallbacks cb;
  const Step23ThreeDaysFree({super.key, required this.cb});
  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 1),
            const _PipIntroBubble(
              lines: [
                'We offer 3 days for free so you can see the results of daily vocabulary learning.',
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 4, dy: 6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Transform.scale(
                scale: 1.25,
                child: Image.asset(
                  'assets/hero-image.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Spacer(flex: 2),
            PrimaryButton(label: 'Try it for free', onPressed: cb.next),
          ],
        ),
      ),
    );
  }
}

// 24. Paywall (annual subscription)
class Step24Trial extends StatelessWidget {
  final StepCallbacks cb;
  const Step24Trial({super.key, required this.cb});

  @override
  Widget build(BuildContext context) {
    return PaywallScreen(
      onDismiss: cb.next,
      onPurchased: cb.next,
    );
  }
}

