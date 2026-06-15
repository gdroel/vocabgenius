import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/home_screen.dart';
import '../notifications/notifications_service.dart';
import '../onboarding/theme.dart';
import '../push_service.dart';
import '../onboarding/widgets.dart';
import '../telemetry.dart';
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
      if (granted) PushService.instance.onNotificationsGranted();
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

  /// Exit-intent offer shown when the user taps the round X on a hard paywall:
  /// a popover pitching the discounted ~$2/mo plan. The dialog closes first and
  /// returns whether the user claimed, so the purchase runs here on the paywall
  /// (a successful buy navigates away via the billing listener / onPurchased).
  Future<void> _showSpecialOffer() async {
    final billing = _billing;
    if (billing == null) return;
    // Warm the discounted product so its real store price is ready.
    billing.loadPipMonthlyTwo();
    final claimed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _SpecialOfferDialog(),
    );
    if (claimed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final ok = await billing.buyPipMonthlyTwo();
      if (ok) Telemetry.monthlyStarted();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    // Live store prices, falling back to list price until the offering resolves.
    final annualPrice = billing?.annualPriceLabel ?? '\$59.99';
    final monthlyPrice = billing?.monthlyPriceLabel ?? '\$4.99';
    // The pitch as styled runs so the prices render bold inside the bubble:
    // "Try 3 days for free, then $4.99 per month. (billed as $59.99 per year)".
    final headlineSegments = <(String, bool)>[
      ('Try 3 days for free, then ', false),
      (monthlyPrice, true),
      (' per month. (billed as ', false),
      (annualPrice, true),
      (' per year)', false),
    ];
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  // In hard-paywall mode there's no plain dismiss; instead a
                  // conspicuous round X reveals a one-time discounted offer.
                  child: _hardPaywall
                      ? _RoundCloseButton(onTap: _showSpecialOffer)
                      : _CloseButton(onTap: widget.onDismiss),
                ),
              ),
              // The pricing pitch as a full-width speech bubble from Professor
              // Pip, who sits above it with the bubble's tail pointing up at him.
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
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
                      ),
                      const SizedBox(height: 6),
                      _PipBubble(segments: headlineSegments, tailOnTop: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
                color: AppColors.forestGreen,
                pulse: true,
              ),
              const SizedBox(height: 16),
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

/// Which one-time offer a push opens the user to. The two differ only in copy,
/// the discount badge, and which product they buy — everything else (layout,
/// navigation, entitlement) is shared.
enum PaywallOffer { monthly, lifetime }

/// No-free-trial paywall opened from a push notification, in two variants:
///   - [PaywallOffer.monthly]:  the $1.99/mo "60% off" professorpipmonthlytwo
///   - [PaywallOffer.lifetime]: the one-time professorpiplifetime purchase
/// Mirrors [PaywallScreen] but swaps the trial timeline for the onboarding
/// lockscreen image. Buying either grants the same Pro entitlement as the
/// annual plan.
class OfferPaywallScreen extends StatefulWidget {
  final PaywallOffer offer;
  const OfferPaywallScreen({super.key, required this.offer});

  @override
  State<OfferPaywallScreen> createState() => _OfferPaywallScreenState();
}

class _OfferPaywallScreenState extends State<OfferPaywallScreen> {
  bool _busy = false;
  bool _wasPro = false;
  BillingService? _billing;

  bool get _isLifetime => widget.offer == PaywallOffer.lifetime;

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
      // Fetch this offer's product so the bubble and button show its real store
      // price; rebuilds via _onBillingChange once it resolves.
      if (_isLifetime) {
        billing.loadLifetime();
      } else {
        billing.loadPipMonthlyTwo();
      }
    }
  }

  @override
  void dispose() {
    _billing?.removeListener(_onBillingChange);
    super.dispose();
  }

  /// Live store price for this offer, falling back to its list price until the
  /// product load resolves.
  String _priceLabel(BillingService? billing) => _isLifetime
      ? (billing?.lifetimePriceLabel ?? '\$9.99')
      : (billing?.pipMonthlyTwoPriceLabel ?? '\$1.99');

  void _onBillingChange() {
    final billing = _billing;
    if (billing == null) return;
    if (!_wasPro && billing.isPro) {
      _wasPro = true;
      // Converting here completes the funnel. Persist onboarding-complete so a
      // later launch skips straight to the app instead of resuming the flow...
      SharedPreferences.getInstance()
          .then((p) => p.setBool('onboarding_completed', true))
          .catchError((_) => false);
      // ...and replace the entire navigation stack with the main app now.
      // pushAndRemoveUntil (not popUntil) because the root route is usually
      // still the onboarding flow when the offer is bought mid-onboarding —
      // popping to it would land back on a paywall step.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
            settings: const RouteSettings(name: 'HomeScreen'),
          ),
          (route) => false,
        );
      }
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _buy() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      if (_isLifetime) {
        final ok = await billing.buyLifetime();
        if (ok) Telemetry.lifetimePurchased();
      } else {
        final ok = await billing.buyPipMonthlyTwo();
        if (ok) Telemetry.monthlyStarted();
      }
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
    final priceLabel = _priceLabel(billing);
    final bubbleText = _isLifetime
        ? 'Special offer just for you, unlock Professor Pip forever!'
        : 'Special offer just for you, daily vocab for just $priceLabel a month!';
    final buttonLabel = _isLifetime
        ? 'Unlock for $priceLabel'
        : 'Unlock for $priceLabel a month';
    final subtext = _isLifetime
        ? 'Pay once, enjoy daily vocab forever'
        : '30-day money-back guarantee, cancel anytime';
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
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
                  Expanded(child: _PipBubble(text: bubbleText)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3870 / 4773, // matches assets/lockscreen.png
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/lockscreen.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        // The 60%-off badge only applies to the monthly offer.
                        if (!_isLifetime)
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
              const SizedBox(height: 10),
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
                label: _busy ? 'Working…' : buttonLabel,
                onPressed: _busy ? null : _buy,
              ),
              const SizedBox(height: 10),
              Text(
                subtext,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
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

class _DiscountBadge extends StatefulWidget {
  const _DiscountBadge();

  @override
  State<_DiscountBadge> createState() => _DiscountBadgeState();
}

class _DiscountBadgeState extends State<_DiscountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1.1)
      .animate(CurvedAnimation(parent: _ctl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Transform.rotate(
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
              '60%',
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
  // Plain bubble text, rendered in the heavy display style. Mutually exclusive
  // with [segments].
  final String? text;
  // Styled run of (text, bold) pairs, rendered in a lighter, more readable Inter
  // style with the bold pieces (e.g. prices) emphasized. Used for the trial
  // pricing headline.
  final List<(String, bool)>? segments;
  // When true the tail points up (Pip sits above a full-width bubble); otherwise
  // it points left (Pip sits beside the bubble).
  final bool tailOnTop;
  const _PipBubble({this.text, this.segments, this.tailOnTop = false})
      : assert(text != null || segments != null,
            'Provide either text or segments');

  /// The full string being typed out, regardless of styling.
  String get plainText =>
      segments != null ? segments!.map((s) => s.$1).join() : text!;

  @override
  State<_PipBubble> createState() => _PipBubbleState();
}

class _PipBubbleState extends State<_PipBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration:
        Duration(milliseconds: (widget.plainText.length * 60).clamp(900, 3200)),
  );
  late final Animation<int> _chars =
      StepTween(begin: 0, end: widget.plainText.length)
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

  /// The portion of the text revealed so far, split into styled spans. Bold
  /// segments (prices) override the weight; the rest inherit [baseStyle].
  List<InlineSpan> _visibleSpans(int shown, TextStyle baseStyle) {
    if (widget.segments == null) {
      return [TextSpan(text: widget.text!.substring(0, shown))];
    }
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w800);
    final spans = <InlineSpan>[];
    var consumed = 0;
    for (final (segText, isBold) in widget.segments!) {
      if (consumed >= shown) break;
      final remaining = shown - consumed;
      final piece =
          segText.length <= remaining ? segText : segText.substring(0, remaining);
      spans.add(TextSpan(text: piece, style: isBold ? boldStyle : null));
      consumed += segText.length;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeechBubblePainter(tailOnTop: widget.tailOnTop),
      child: Padding(
        padding: widget.tailOnTop
            ? const EdgeInsets.fromLTRB(20, 28, 20, 18)
            : const EdgeInsets.fromLTRB(26, 14, 18, 16),
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
              final isTyping = _chars.value < widget.plainText.length;
              // Segments use a lighter, more readable Inter face; plain text
              // keeps the heavy display style used by the other Pip bubbles.
              final baseStyle = widget.segments != null
                  ? GoogleFonts.inter(
                      color: AppColors.ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    )
                  : const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    );
              return RichText(
                text: TextSpan(
                  style: baseStyle,
                  children: [
                    ..._visibleSpans(_chars.value, baseStyle),
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
  // When true the tail points up from the top edge; otherwise left from the
  // left edge.
  final bool tailOnTop;
  const _SpeechBubblePainter({this.tailOnTop = false});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(22);
    final path = tailOnTop ? _topTailPath(size, radius) : _leftTailPath(size, radius);

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

  // Tail on the left edge, pointing left toward a Pip avatar beside the bubble.
  Path _leftTailPath(Size size, Radius radius) {
    const tailWidth = 14.0;
    const tailHeight = 26.0;
    final tailCenterY = size.height / 2;
    final bodyLeft = tailWidth;
    return Path()
      ..moveTo(bodyLeft + radius.x, 0)
      ..lineTo(size.width - radius.x, 0)
      ..arcToPoint(Offset(size.width, radius.y), radius: radius)
      ..lineTo(size.width, size.height - radius.y)
      ..arcToPoint(Offset(size.width - radius.x, size.height), radius: radius)
      ..lineTo(bodyLeft + radius.x, size.height)
      ..arcToPoint(Offset(bodyLeft, size.height - radius.y), radius: radius)
      // Down the left edge to the tail bottom, out to the tip, back up.
      ..lineTo(bodyLeft, tailCenterY + tailHeight / 2)
      ..lineTo(0, tailCenterY)
      ..lineTo(bodyLeft, tailCenterY - tailHeight / 2)
      ..lineTo(bodyLeft, radius.y)
      ..arcToPoint(Offset(bodyLeft + radius.x, 0), radius: radius)
      ..close();
  }

  // Tail on the top edge, pointing up toward a Pip avatar above the bubble.
  Path _topTailPath(Size size, Radius radius) {
    const tailWidth = 26.0;
    const tailHeight = 14.0;
    final tailCenterX = size.width / 2;
    final bodyTop = tailHeight;
    return Path()
      ..moveTo(radius.x, bodyTop)
      // Along the top edge to the tail base, up to the tip, back down.
      ..lineTo(tailCenterX - tailWidth / 2, bodyTop)
      ..lineTo(tailCenterX, 0)
      ..lineTo(tailCenterX + tailWidth / 2, bodyTop)
      ..lineTo(size.width - radius.x, bodyTop)
      ..arcToPoint(Offset(size.width, bodyTop + radius.y), radius: radius)
      ..lineTo(size.width, size.height - radius.y)
      ..arcToPoint(Offset(size.width - radius.x, size.height), radius: radius)
      ..lineTo(radius.x, size.height)
      ..arcToPoint(Offset(0, size.height - radius.y), radius: radius)
      ..lineTo(0, bodyTop + radius.y)
      ..arcToPoint(Offset(radius.x, bodyTop), radius: radius)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) =>
      oldDelegate.tailOnTop != tailOnTop;
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

/// A conspicuous round close button — white fill, thick border, hard shadow —
/// used on the hard paywall, where it opens the special-offer popover.
class _RoundCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RoundCloseButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close, size: 26, color: AppColors.burgundy),
      ),
    );
  }
}

/// Exit-intent popover offering the discounted ~$2/mo plan, fronted by a Lottie
/// gift-opening animation. Pops `true` when the user taps claim (the caller then
/// runs the purchase), or `false`/barrier-dismiss to decline.
class _SpecialOfferDialog extends StatelessWidget {
  const _SpecialOfferDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cream,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 160,
              child: Lottie.asset(
                'assets/lottie/gift.json',
                fit: BoxFit.contain,
                // Until a real gift Lottie is dropped in, fall back to the
                // static gift image so the popover never renders broken.
                errorBuilder: (_, _, _) =>
                    Image.asset('assets/gift.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Wait, don't leave!",
              textAlign: TextAlign.center,
              style: appText(size: 24, weight: FontWeight.w800, height: 1.15),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                children: const [
                  TextSpan(text: 'Take '),
                  TextSpan(
                    text: '60% off',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ' Professor Pip, forever. Just '),
                  TextSpan(
                    text: '\$2 a month',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: ', cancel anytime.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Try for \$2 a month',
              color: AppColors.forestGreen,
              pulse: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'No thanks',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
