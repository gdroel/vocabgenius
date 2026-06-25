import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Chip;
import 'package:flutter/services.dart';
import '../../billing/paywall_screen.dart';
import '../../notifications/notifications_service.dart';
import '../../push_service.dart';
import '../../telemetry.dart';
import '../../topics/topics_catalog.dart';
import '../../topics/topics_repository.dart';
import '../../topics/words_data.dart';
import '../../user_profile.dart';
import '../flow.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

// Reusable layout: hero illustration + title + continue button
class _IntroScreen extends StatelessWidget {
  final StepCallbacks cb;
  final IconData icon;
  final String title;
  const _IntroScreen({
    required this.cb,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      showBack: !cb.isFirst,
      onSkip: cb.skip,
      showSkip: true,
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
                    TitleHeader(title: title),
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
                // Room so the tiles' hard shadow (offset down-right) isn't
                // clipped by the list's edge.
                padding: const EdgeInsets.fromLTRB(4, 2, 6, 8),
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
  final List<String> options;
  final Set<String> Function(OnboardingData) read;
  final bool showSkip;
  /// Optional difficulty badge shown above the title (e.g. "Beginner words").
  final String? pill;
  const _MultiChoiceScreen({
    required this.cb,
    required this.title,
    required this.options,
    required this.read,
    this.showSkip = true,
    this.pill,
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
            if (widget.pill != null) ...[
              Center(child: _DifficultyPill(text: widget.pill!)),
              const SizedBox(height: 14),
            ],
            TitleHeader(title: widget.title),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                // Room so the tiles' hard shadow (offset down-right) isn't
                // clipped by the list's edge.
                padding: const EdgeInsets.fromLTRB(4, 2, 6, 8),
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

/// A small difficulty badge (e.g. "Beginner words") shown above the
/// "Select all the words you know" instruction on the word-list screens.
class _DifficultyPill extends StatelessWidget {
  final String text;
  const _DifficultyPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.burgundy,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 2, dy: 3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.cream,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.3,
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
                fontSize: 22,
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
              PrimaryButton(label: 'Nice to meet you, Pip!', onPressed: cb.next),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipIntroBubble extends StatefulWidget {
  final List<String> lines;
  final double fontSize;
  const _PipIntroBubble({super.key, required this.lines, this.fontSize = 17});

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
      .animate(CurvedAnimation(parent: _ctl, curve: Curves.linear));

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
              final style = TextStyle(
                color: AppColors.ink,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                height: 1.4,
              );
              final shown = _full.substring(0, _chars.value);
              final isTyping = _chars.value < _full.length;
              final reveal = RichText(
                text: TextSpan(
                  style: style,
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
              // Reserve the final size with an invisible copy of the full text
              // so the bubble never reflows as it types (the cause of the jerk).
              return Stack(
                children: [
                  Opacity(opacity: 0, child: Text(_full, style: style)),
                  Positioned.fill(child: reveal),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}


/// Professor Pip avatar on the left with a speech bubble (tail pointing at
/// him) on the right — frees vertical space so a screen's main visual can be
/// larger. Same look as the paywall.
class _PipSpeechRow extends StatelessWidget {
  final List<String> lines;
  final Color textColor;
  final double fontSize;
  const _PipSpeechRow({
    super.key,
    required this.lines,
    this.textColor = AppColors.ink,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Brutal.borderColor,
              width: Brutal.borderWidth,
            ),
            boxShadow: Brutal.shadow(dx: 2, dy: 3),
          ),
          clipBehavior: Clip.antiAlias,
          child: Transform.scale(
            scale: 1.25,
            child: Image.asset('assets/hero-image.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _TailedPipBubble(
            lines: lines,
            textColor: textColor,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}

class _TailedPipBubble extends StatefulWidget {
  final List<String> lines;
  final Color textColor;
  final double fontSize;
  const _TailedPipBubble({
    required this.lines,
    this.textColor = AppColors.ink,
    this.fontSize = 17,
  });

  @override
  State<_TailedPipBubble> createState() => _TailedPipBubbleState();
}

class _TailedPipBubbleState extends State<_TailedPipBubble>
    with SingleTickerProviderStateMixin {
  late final String _full = widget.lines.join('\n\n');
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_full.length * 22).clamp(900, 3200)),
  );
  late final Animation<int> _chars = StepTween(begin: 0, end: _full.length)
      .animate(CurvedAnimation(parent: _ctl, curve: Curves.linear));

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
    return CustomPaint(
      painter: _SpeechBubblePainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 14, 18, 16),
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
            const SizedBox(height: 6),
            AnimatedBuilder(
              animation: _chars,
              builder: (_, _) {
                final style = TextStyle(
                  color: widget.textColor,
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                );
                final shown = _full.substring(0, _chars.value);
                final isTyping = _chars.value < _full.length;
                final reveal = RichText(
                  text: TextSpan(
                    style: style,
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
                // Reserve the final size with an invisible copy of the full
                // text so the bubble never reflows as it types.
                return Stack(
                  children: [
                    Opacity(opacity: 0, child: Text(_full, style: style)),
                    Positioned.fill(child: reveal),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 14.0;
    const tailHeight = 26.0;
    const radius = Radius.circular(22);
    final tailCenterY = size.height / 2;
    const bodyLeft = tailWidth;

    final path = Path()
      ..moveTo(bodyLeft + radius.x, 0)
      ..lineTo(size.width - radius.x, 0)
      ..arcToPoint(Offset(size.width, radius.y), radius: radius)
      ..lineTo(size.width, size.height - radius.y)
      ..arcToPoint(Offset(size.width - radius.x, size.height), radius: radius)
      ..lineTo(bodyLeft + radius.x, size.height)
      ..arcToPoint(Offset(bodyLeft, size.height - radius.y), radius: radius)
      ..lineTo(bodyLeft, tailCenterY + tailHeight / 2)
      ..lineTo(0, tailCenterY)
      ..lineTo(bodyLeft, tailCenterY - tailHeight / 2)
      ..lineTo(bodyLeft, radius.y)
      ..arcToPoint(Offset(bodyLeft + radius.x, 0), radius: radius)
      ..close();

    canvas.drawPath(
      path.shift(const Offset(3, 4)),
      Paint()
        ..color = Brutal.borderColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Brutal.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = Brutal.borderWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    _ctl = TextEditingController(text: UserProfile.firstName);
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
                onChanged: (v) {
                  data.update(() => data.name = v);
                  UserProfile.save(v);
                },
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
              onPressed: data.name.trim().isEmpty
                  ? null
                  : () {
                      // Record the chosen name as a server-side event.
                      Telemetry.nameEntered(data.name.trim());
                      widget.cb.next();
                    },
              enabled: data.name.trim().isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }
}

// 4b. Lockscreen preview
class Step04bLockscreenIntro extends StatelessWidget {
  final StepCallbacks cb;
  const Step04bLockscreenIntro({super.key, required this.cb});

  @override
  Widget build(BuildContext context) {
    final name = OnboardingScope.of(context).name.trim();
    final line = name.isEmpty
        ? 'Learn a new word on the lockscreen widget every hour.'
        : 'Hey $name! Learn a new word on the lockscreen widget every hour.';
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      onSkip: cb.skip,
      showSkip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _PipSpeechRow(
              key: ValueKey(line),
              lines: [line],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/lockscreen.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Nice!',
              onPressed: () {
                cb.next();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 4c. Word of the day notification opt-in
class Step04cWordOfDayNotification extends StatefulWidget {
  final StepCallbacks cb;
  const Step04cWordOfDayNotification({super.key, required this.cb});

  @override
  State<Step04cWordOfDayNotification> createState() =>
      _Step04cWordOfDayNotificationState();
}

class _Step04cWordOfDayNotificationState
    extends State<Step04cWordOfDayNotification> {
  bool _busy = false;

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    final data = OnboardingScope.of(context);
    bool granted;
    try {
      granted = await NotificationsService.instance.requestIosPermission();
    } catch (_) {
      granted = false;
    }
    if (granted) PushService.instance.onNotificationsGranted();
    if (!mounted) return;
    data.update(() => data.notificationsEnabled = granted);
    widget.cb.next();
  }

  void _skip() {
    final data = OnboardingScope.of(context);
    data.update(() => data.notificationsEnabled = false);
    widget.cb.next();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      showSkip: true,
      onSkip: _busy ? null : _skip,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TitleHeader(
              title: 'Get a Personalized Word\nof the Day Notification',
              fitTitle: true,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/wordoftheday.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: _busy ? 'Turning on…' : 'Get word of the day',
              onPressed: _busy ? null : _enable,
              enabled: !_busy,
              color: AppColors.forestGreen,
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'One notification a day. No spam, ever.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      onSkip: cb.skip,
      showSkip: true,
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
      onSkip: cb.skip,
      showSkip: true,
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
      onSkip: cb.skip,
      showSkip: true,
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
      onSkip: () {
        // Skipping selects every category by default.
        repo.setAll(TopicsCatalog.all.map((t) => t.id));
        widget.cb.skip();
      },
      showSkip: true,
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
                        (t) => TopicChip(
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
    pill: 'Beginner words',
    title: 'Select all the\nwords you know',
    options: const [
      'Eager',
      'Vivid',
      'Brisk',
      'Hollow',
      'Mellow',
      'Dwindle',
    ],
    read: (d) => d.beginnerKnown,
    showSkip: true,
  );
}

// 18. Intermediate words
class Step18IntermediateWords extends StatelessWidget {
  final StepCallbacks cb;
  const Step18IntermediateWords({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    pill: 'Intermediate words',
    title: 'Select all the\nwords you know',
    options: const [
      'Ephemeral',
      'Candid',
      'Astute',
      'Beguile',
      'Tacit',
      'Wistful',
    ],
    read: (d) => d.intermediateKnown,
    showSkip: true,
  );
}

// 19. Advanced words
class Step19AdvancedWords extends StatelessWidget {
  final StepCallbacks cb;
  const Step19AdvancedWords({super.key, required this.cb});
  @override
  Widget build(BuildContext context) => _MultiChoiceScreen(
    cb: cb,
    pill: 'Advanced words',
    title: 'Select all the\nwords you know',
    options: const [
      'Petrichor',
      'Sonder',
      'Sesquipedalian',
      'Susurrus',
      'Apricity',
      'Defenestrate',
    ],
    read: (d) => d.advancedKnown,
    showSkip: true,
  );
}

// 21. Building plan (loading) — Pip speaks over a storm of flying vocab words.
class Step21BuildingPlan extends StatefulWidget {
  final StepCallbacks cb;
  const Step21BuildingPlan({super.key, required this.cb});
  @override
  State<Step21BuildingPlan> createState() => _Step21BuildingPlanState();
}

class _Step21BuildingPlanState extends State<Step21BuildingPlan>
    with TickerProviderStateMixin {
  late final AnimationController _ac;
  late final AnimationController _glow;
  @override
  void initState() {
    super.initState();
    // 30% faster than the previous 8s.
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..forward();
    _ac.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) widget.cb.next();
    });
    // Repeating pulse that makes the bar glow.
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      progress: widget.cb.progress,
      onBack: widget.cb.back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The word storm only fills the area above the progress bar, so no
          // words ever pass behind it.
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: _WordStorm()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Spacer(flex: 2),
                      _PipSpeechRow(
                        textColor: Colors.black,
                        fontSize: 22,
                        lines: [
                          "Hang tight! I'm building your personalized plan.",
                        ],
                      ),
                      Spacer(flex: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: AnimatedBuilder(
              animation: Listenable.merge([_ac, _glow]),
              builder: (_, _) {
                final g = Curves.easeInOut.transform(_glow.value);
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forestGreen
                            .withValues(alpha: 0.25 + 0.5 * g),
                        blurRadius: 8 + 16 * g,
                        spreadRadius: 0.5 + 2.5 * g,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _ac.value,
                      minHeight: 10,
                      backgroundColor: AppColors.creamSoft,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.forestGreen),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// All-black vocabulary words streaming horizontally across the screen in
/// parallax lanes — fading in at one edge and out the other, like words being
/// filed into a schedule. Within each lane words are spaced by their own width
/// plus a fixed gap, so they never overlap; lanes are spaced taller than the
/// type so neighbouring rows never collide either. A backdrop for the
/// plan-building loader: words are laid out once and re-drawn via canvas
/// transforms, and the field is masked to fade at the left/right edges.
class _WordStorm extends StatefulWidget {
  const _WordStorm();

  @override
  State<_WordStorm> createState() => _WordStormState();
}

class _WordStormState extends State<_WordStorm>
    with SingleTickerProviderStateMixin {
  static const _words = [
    'Ephemeral', 'Sonder', 'Petrichor', 'Eloquent', 'Lucid', 'Serendipity',
    'Nuance', 'Mellifluous', 'Ineffable', 'Quixotic', 'Halcyon', 'Aplomb',
    'Sublime', 'Verbose', 'Cogent', 'Pithy', 'Astute', 'Candor',
    'Eclectic', 'Fervent', 'Gregarious', 'Idyllic', 'Jubilant', 'Keen',
    'Limpid', 'Myriad', 'Nimble', 'Opulent', 'Pensive', 'Quaint',
    'Resolute', 'Salient', 'Tenacious', 'Urbane', 'Vivid', 'Whimsical',
    'Zealous', 'Ardent', 'Brisk', 'Cardinal', 'Deft', 'Erudite',
    'Fluent', 'Genteel', 'Lithe', 'Sage', 'Vibrant', 'Witty',
  ];

  // All words are black; lanes differ only by opacity (depth), so a few alpha
  // buckets baked into the painters cover the whole field with no per-frame
  // re-layout or compositing.
  static const _bucketAlphas = [0.32, 0.5, 0.7, 0.92];
  static const _baseSize = 20.0;
  static const _laneCount = 14;
  static const _gap = 44.0; // min horizontal gap between adjacent words (px)
  static const _wordsPerLane = 26;

  late final AnimationController _ctl;
  late final List<TextPainter> _painters;
  late final List<_Lane> _lanes;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();
    _painters = _layoutPainters();
    _lanes = _buildLanes();
  }

  List<TextPainter> _layoutPainters() {
    final out = <TextPainter>[];
    for (final word in _words) {
      for (final a in _bucketAlphas) {
        out.add(
          TextPainter(
            text: TextSpan(
              text: word,
              style: appText(
                size: _baseSize,
                weight: FontWeight.w700,
                color: Colors.black.withValues(alpha: a),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        );
      }
    }
    return out;
  }

  List<_Lane> _buildLanes() {
    final rnd = math.Random(11);
    final bucketCount = _bucketAlphas.length;
    return List.generate(_laneCount, (i) {
      // Spread depth across lanes (golden-ratio hop) so neighbours differ.
      final depth = 0.2 + ((i * 0.61803398875 + 0.21) % 1.0) * 0.8;
      final bucket = (depth * (bucketCount - 1)).round();
      final scale = (12.0 + depth * 8.0) / _baseSize; // font 12..20
      // Lay the lane's words end to end, each separated by its own width plus a
      // gap, so nothing in the lane ever overlaps. Positions are screen-space.
      final slots = <_Slot>[];
      var cursor = 0.0;
      for (var k = 0; k < _wordsPerLane; k++) {
        final word = rnd.nextInt(_words.length);
        final painterIndex = word * bucketCount + bucket;
        slots.add(_Slot(painterIndex, cursor));
        cursor += _painters[painterIndex].width * scale + _gap;
      }
      return _Lane(
        scale: scale,
        dir: i.isEven ? 1 : -1, // alternate lanes flow opposite ways
        speed: 14.0 + depth * 30.0, // px/sec; closer (darker) lanes go faster
        length: cursor, // full track length, including the trailing gap
        slots: slots,
      );
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // Fade words in and out at the left/right edges as they fly across.
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.1, 0.9, 1.0],
      ).createShader(rect),
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, _) => CustomPaint(
          painter: _WordStormPainter(
            t: _ctl.value * 90.0,
            lanes: _lanes,
            painters: _painters,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Slot {
  final int painterIndex;
  final double left; // left edge along the lane's track, in screen px
  const _Slot(this.painterIndex, this.left);
}

class _Lane {
  final double scale;
  final int dir;
  final double speed;
  final double length;
  final List<_Slot> slots;
  const _Lane({
    required this.scale,
    required this.dir,
    required this.speed,
    required this.length,
    required this.slots,
  });
}

class _WordStormPainter extends CustomPainter {
  final double t;
  final List<_Lane> lanes;
  final List<TextPainter> painters;
  const _WordStormPainter({
    required this.t,
    required this.lanes,
    required this.painters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 90.0;
    const topInset = 14.0;
    const bottomInset = 10.0;
    const bob = 2.5;
    final laneCount = lanes.length;
    final usable = size.height - topInset - bottomInset;

    // Faint ruled rows, like a schedule the words are filing into.
    final rule = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 1; i < laneCount; i++) {
      final y = topInset + usable * i / laneCount;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    for (var i = 0; i < laneCount; i++) {
      final lane = lanes[i];
      final baseY = topInset + usable * (i + 0.5) / laneCount;
      final L = lane.length;
      for (var k = 0; k < lane.slots.length; k++) {
        final slot = lane.slots[k];
        // Scroll the whole track; Dart's % is non-negative for positive L.
        final x = ((slot.left + lane.dir * lane.speed * t) % L) - margin;
        final tp = painters[slot.painterIndex];
        final w = tp.width * lane.scale;
        if (x > size.width + margin || x + w < -margin) continue; // off-screen
        final y = baseY + math.sin(t * 0.5 + i * 1.7 + k * 0.9) * bob;
        canvas.save();
        canvas.translate(x, y);
        if (lane.scale != 1.0) canvas.scale(lane.scale);
        tp.paint(canvas, Offset(0, -tp.height / 2));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WordStormPainter oldDelegate) =>
      oldDelegate.t != t;
}

// 22. Become more articulate — Pip pitch
class Step22OneMinuteADay extends StatelessWidget {
  final StepCallbacks cb;
  const Step22OneMinuteADay({super.key, required this.cb});
  @override
  Widget build(BuildContext context) {
    final name = OnboardingScope.of(context).name.trim();
    final line = name.isEmpty
        ? "You'll become more articulate in just 1 minute a day, without even opening the app."
        : "$name, you'll become more articulate in just 1 minute a day — without even opening the app.";
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      onSkip: cb.skip,
      showSkip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 1),
            _PipIntroBubble(
              key: ValueKey(line),
              lines: [line],
              fontSize: 22,
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

// 22b. Personalized plan summary — recaps what we set up before the trial pitch.
class Step22bPlanReady extends StatelessWidget {
  final StepCallbacks cb;
  const Step22bPlanReady({super.key, required this.cb});
  @override
  Widget build(BuildContext context) {
    final data = OnboardingScope.of(context);
    final followed = TopicsScope.of(context).followed;
    final titles = {for (final t in TopicsCatalog.all) t.id: t.title};
    final topicNames = followed.map((id) => titles[id] ?? id).toList();
    final topicsText = topicNames.isEmpty
        ? 'Tailored to you'
        : topicNames.length <= 2
        ? topicNames.join(' and ')
        : '${topicNames.take(2).join(', ')} +${topicNames.length - 2} more';
    final remindersText =
        data.notificationsEnabled ? 'Daily word of the day' : 'Not set yet';
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      onSkip: cb.skip,
      showSkip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 1),
            const TitleHeader(
              title: 'Your personalized\nplan is ready',
              subtitle: 'Enjoy it for free with a 3-day trial',
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 4, dy: 6),
              ),
              child: Column(
                children: [
                  const _PlanRow(
                    icon: Icons.track_changes,
                    label: 'Your level',
                    value: 'Intermediate to Advanced',
                  ),
                  _PlanRow(
                    icon: Icons.grid_view_rounded,
                    label: 'Topics of interest',
                    value: topicsText,
                  ),
                  _PlanRow(
                    icon: Icons.notifications_outlined,
                    label: 'Your reminders',
                    value: remindersText,
                  ),
                ],
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

// A single labelled row inside the personalized-plan card.
class _PlanRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: AppColors.forestGreen),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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

// 23. Three days free — Pip pitch over a live lockscreen demo of the widget.
class Step23ThreeDaysFree extends StatelessWidget {
  final StepCallbacks cb;
  const Step23ThreeDaysFree({super.key, required this.cb});
  @override
  Widget build(BuildContext context) {
    final name = OnboardingScope.of(context).name.trim();
    final line = name.isEmpty
        ? 'Your first 3 days are on me, see what daily vocab can do for you!'
        : '$name, your first 3 days are on me, see what daily vocab can do for you!';
    // Cycle the words from the topics the user just chose (falling back to all),
    // keeping definitions short enough to read at a glance on the widget.
    final followed = TopicsScope.of(context).followed;
    var pool = (followed.isNotEmpty ? WordsData.forTopics(followed) : WordsData.all)
        .where((w) => w.definition.length <= 78 && w.word.length <= 16)
        .toList();
    if (pool.isEmpty) pool = WordsData.all.toList();
    pool.shuffle(math.Random(7));
    final words = pool.take(24).toList();
    return OnboardingScaffold(
      progress: cb.progress,
      onBack: cb.back,
      onSkip: cb.skip,
      showSkip: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PipSpeechRow(key: ValueKey(line), lines: [line], fontSize: 18),
            const SizedBox(height: 16),
            Expanded(child: _MockLockscreen(words: words)),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Try it for free',
              onPressed: cb.next,
              color: AppColors.forestGreen,
            ),
          ],
        ),
      ),
    );
  }
}

// The iOS system font (San Francisco) so the mock clock/widget look real.
const String _sfDisplay = '.SF Pro Display';
const String _sfText = '.SF Pro Text';

/// A mock of the TOP HALF of an iOS lockscreen — just the clock and a Professor
/// Pip text widget beneath it. Full width (matching the bubble/button); the
/// word changes every few seconds while the hour ticks 12 → 1 → 2 … alongside
/// it, to show the everyday value of the lock-screen widget during onboarding.
class _MockLockscreen extends StatefulWidget {
  final List<Word> words;
  const _MockLockscreen({required this.words});

  @override
  State<_MockLockscreen> createState() => _MockLockscreenState();
}

class _MockLockscreenState extends State<_MockLockscreen> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _shadow = [Shadow(color: Colors.black38, blurRadius: 10)];

  int _i = 0;
  Timer? _timer;
  late final int _startHour; // nearest hour (24h), e.g. 7:36 → 8
  late final String _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startHour = now.hour + (now.minute >= 30 ? 1 : 0);
    _date = '${_weekdays[now.weekday - 1]} ${_months[now.month - 1]} ${now.day}';
    // New word every 3 seconds; the hour ticks forward with it.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.words.isEmpty) return;
      setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.words;
    final word = words.isEmpty ? null : words[_i % words.length];
    final hour24 = (_startHour + _i) % 24;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12; // 12-hour, on the hour

    // Black phone frame with the real iPhone top corner radius and a bezel on
    // the top/sides only — the bottom is left open so it reads as the screen
    // continuing past a straight cut-off edge (just the top half of the phone).
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(52)),
      ),
      padding: const EdgeInsets.only(top: 7, left: 7, right: 7),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(46)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  // A gradient built around #545AD2 (indigo).
                  colors: [Color(0xFF6E74E6), Color(0xFF545AD2), Color(0xFF3A3F9E)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 60, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _date,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: _sfText,
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: _shadow,
                    ),
                  ),
                  Text(
                    '$hour:00',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: _sfDisplay,
                      color: Colors.white,
                      fontSize: 96,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      letterSpacing: -2,
                      shadows: _shadow,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The Pip text widget sits directly under the clock.
                  SizedBox(
                    height: 62,
                    child: word == null
                        ? null
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topLeft,
                              children: [...previous, ?current],
                            ),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.18),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: _PipTextWidget(key: ValueKey(_i), word: word),
                          ),
                  ),
                ],
              ),
            ),
            // The Dynamic Island: a compact black pill (~126×37pt on a real
            // ~393pt-wide screen ≈ 32% width), sitting ~11pt from the top.
            Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.32,
                  child: AspectRatio(
                    aspectRatio: 126 / 37,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Professor Pip lock-screen text widget: the word, then "(pos) definition"
/// — plain white text on the wallpaper, exactly as iOS renders a text widget.
class _PipTextWidget extends StatelessWidget {
  final Word word;
  const _PipTextWidget({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black38, blurRadius: 8)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          word.word,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: _sfText,
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            shadows: shadow,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '(${word.partOfSpeech}) ${word.definition}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: _sfText,
            color: Colors.white,
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w500,
            shadows: shadow,
          ),
        ),
      ],
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

