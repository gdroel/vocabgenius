import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../notifications/notifications_service.dart';
import '../onboarding/theme.dart';
import '../onboarding/widgets.dart';
import '../telemetry.dart';
import '../user_profile.dart';
import 'billing_service.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onPurchased;
  const PaywallScreen({
    super.key,
    required this.onDismiss,
    required this.onPurchased,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _busy = false;
  bool _wasPro = false;
  bool _reminderBeforeTrialEnds = false;
  bool _hardPaywall = false;
  BillingService? _billing;

  @override
  void initState() {
    super.initState();
    Telemetry.paywallReached();
    Posthog().isFeatureEnabled('hard-paywall').then((enabled) {
      if (!mounted) return;
      setState(() => _hardPaywall = enabled);
    }).catchError((_) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final billing = BillingScope.of(context);
    if (!identical(billing, _billing)) {
      _billing?.removeListener(_onBillingChange);
      _billing = billing;
      _wasPro = billing.isPro;
      billing.addListener(_onBillingChange);
    }
  }

  @override
  void dispose() {
    _billing?.removeListener(_onBillingChange);
    super.dispose();
  }

  void _onBillingChange() {
    final billing = _billing;
    if (billing == null) return;
    if (!_wasPro && billing.isPro) {
      _wasPro = true;
      widget.onPurchased();
    }
    if (mounted) setState(() {});
  }

  Future<void> _buy() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      final ok = await billing.buyAnnual();
      if (ok) Telemetry.annualTrialStarted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onReminderToggle(bool desired) async {
    if (desired) {
      final granted = await NotificationsService.instance
          .requestIosPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() => _reminderBeforeTrialEnds = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable notifications in Settings to get the reminder.'),
          ),
        );
        return;
      }
      await NotificationsService.instance.scheduleTrialReminder();
      if (!mounted) return;
      setState(() => _reminderBeforeTrialEnds = true);
    } else {
      await NotificationsService.instance.cancelTrialReminder();
      if (!mounted) return;
      setState(() => _reminderBeforeTrialEnds = false);
    }
  }

  Future<void> _restore() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      await billing.restore();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 28,
                child: _hardPaywall
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _CloseButton(onTap: widget.onDismiss),
                      ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
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
                      scale: 1.3,
                      child: Image.asset(
                        'assets/hero-image.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PipBubble(
                      text: UserProfile.firstName.isEmpty
                          ? 'Enjoy your free trial!'
                          : 'Enjoy your free trial, ${UserProfile.firstName}!',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Timeline(showReminder: _hardPaywall),
              const Spacer(flex: 1),
              if (_hardPaywall) ...[
                _ReminderToggle(
                  value: _reminderBeforeTrialEnds,
                  onChanged: _onReminderToggle,
                ),
                const SizedBox(height: 10),
              ],
              if (billing?.lastError != null && !(billing?.isPro ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    billing!.lastError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 13,
                    ),
                  ),
                ),
              PrimaryButton(
                label: _busy ? 'Working…' : 'Try for \$0.00',
                onPressed: _busy ? null : _buy,
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  style: TextStyle(color: AppColors.ink, fontSize: 14),
                  children: [
                    TextSpan(text: '\$4.99 a month, billed yearly as '),
                    TextSpan(
                      text: '\$59.99 per year',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _busy ? null : _restore,
                child: const Text(
                  'Privacy   Terms & Conditions   Restore',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monthly, no-free-trial paywall opened from a push notification.
/// Mirrors [PaywallScreen] but swaps the trial timeline for the onboarding
/// lockscreen image and adds a 30-day money-back guarantee. Buying grants the
/// same Pro entitlement as the annual plan.
class MonthlyPaywallScreen extends StatefulWidget {
  const MonthlyPaywallScreen({super.key});

  @override
  State<MonthlyPaywallScreen> createState() => _MonthlyPaywallScreenState();
}

class _MonthlyPaywallScreenState extends State<MonthlyPaywallScreen> {
  bool _busy = false;
  bool _wasPro = false;
  BillingService? _billing;

  @override
  void initState() {
    super.initState();
    Telemetry.notificationScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final billing = BillingScope.of(context);
    if (!identical(billing, _billing)) {
      _billing?.removeListener(_onBillingChange);
      _billing = billing;
      _wasPro = billing.isPro;
      billing.addListener(_onBillingChange);
    }
  }

  @override
  void dispose() {
    _billing?.removeListener(_onBillingChange);
    super.dispose();
  }

  void _onBillingChange() {
    final billing = _billing;
    if (billing == null) return;
    if (!_wasPro && billing.isPro) {
      _wasPro = true;
      // Pop every pushed route (this screen + any paywall underneath) back to
      // the root, which now renders the main app experience since isPro is true.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _buy() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      final ok = await billing.buyPipMonthly();
      if (ok) Telemetry.monthlyStarted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      await billing.restore();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
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
                      scale: 1.3,
                      child: Image.asset(
                        'assets/hero-image.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: _PipBubble(
                      text: 'We have a special offer for you, '
                          'get daily vocab words for just \$5 a month!',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1419 / 1046, // matches assets/lockscreen.png
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/lockscreen.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Positioned(
                          top: -6,
                          right: -6,
                          child: _DiscountBadge(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (billing?.lastError != null && !(billing?.isPro ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    billing!.lastError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 13,
                    ),
                  ),
                ),
              PrimaryButton(
                label: _busy ? 'Working…' : 'Sign Up',
                onPressed: _busy ? null : _buy,
              ),
              const SizedBox(height: 10),
              const Text(
                '30-day money-back guarantee',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _busy ? null : _restore,
                child: const Text(
                  'Privacy   Terms & Conditions   Restore',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.18,
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '50%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            Text(
              'OFF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final bool showReminder;
  const _Timeline({this.showReminder = false});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final reminder = now.add(const Duration(days: 2));
    final billing = now.add(const Duration(days: 3));
    final items = [
      ('Install the app', 'Set it up to match your needs', Icons.download_rounded),
      ('Today - Free trial starts', 'Get full access', Icons.lock_open_rounded),
      if (showReminder)
        ('${_fmt(reminder)} - Trial reminder', "We'll remind you before it ends", Icons.notifications_active_rounded),
      ('${_fmt(billing)} - Become member', "You're official!", Icons.workspace_premium_rounded),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 3, dy: 4),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: i < 2 ? AppColors.success : AppColors.creamSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          items[i].$3,
                          size: 12,
                          color: i < 2 ? Colors.white : AppColors.muted,
                        ),
                      ),
                      if (i < items.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: i < 1
                                ? AppColors.success
                                : AppColors.creamSoft,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 2,
                        bottom: i < items.length - 1 ? 16 : 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].$1,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$2,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
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

class _ReminderToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ReminderToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 3, dy: 4),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Reminder before trial ends',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipBubble extends StatefulWidget {
  final String text;
  const _PipBubble({required this.text});

  @override
  State<_PipBubble> createState() => _PipBubbleState();
}

class _PipBubbleState extends State<_PipBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.text.length * 60).clamp(900, 3200)),
  );
  late final Animation<int> _chars =
      StepTween(begin: 0, end: widget.text.length)
          .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOut));

  int _lastTickedAt = 0;

  @override
  void initState() {
    super.initState();
    _chars.addListener(() {
      final shown = _chars.value;
      if (shown > _lastTickedAt && shown - _lastTickedAt >= 2) {
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _chars,
            builder: (_, _) {
              final shown = widget.text.substring(0, _chars.value);
              final isTyping = _chars.value < widget.text.length;
              return RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
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
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 14.0;
    const tailHeight = 26.0;
    final radius = const Radius.circular(22);
    final tailCenterY = size.height / 2;
    final bodyLeft = tailWidth;

    final path = Path()
      // Start at top-left of body (after rounding)
      ..moveTo(bodyLeft + radius.x, 0)
      ..lineTo(size.width - radius.x, 0)
      ..arcToPoint(
        Offset(size.width, radius.y),
        radius: radius,
      )
      ..lineTo(size.width, size.height - radius.y)
      ..arcToPoint(
        Offset(size.width - radius.x, size.height),
        radius: radius,
      )
      ..lineTo(bodyLeft + radius.x, size.height)
      ..arcToPoint(
        Offset(bodyLeft, size.height - radius.y),
        radius: radius,
      )
      // Down the left edge to the tail bottom
      ..lineTo(bodyLeft, tailCenterY + tailHeight / 2)
      // Out to the tail tip
      ..lineTo(0, tailCenterY)
      // Back up to the tail top
      ..lineTo(bodyLeft, tailCenterY - tailHeight / 2)
      // Up to the top-left corner
      ..lineTo(bodyLeft, radius.y)
      ..arcToPoint(
        Offset(bodyLeft + radius.x, 0),
        radius: radius,
      )
      ..close();

    // Drop shadow
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

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.close, size: 24, color: AppColors.burgundy),
      ),
    );
  }
}
