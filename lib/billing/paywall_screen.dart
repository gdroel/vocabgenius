import 'dart:async';

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
import 'legal_screen.dart';

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
  // App Store review mode: shows explicit annual pricing + functional legal /
  // restore links, and closing the paywall just enters the app (no retention
  // offer). Flip the "inreview" flag off for real users.
  bool _inReview = false;
  // True while the special-offer popover is up: it drives its own purchase and
  // navigation, so the paywall's auto-onPurchased must stand down to avoid two
  // navigations fighting over the same route stack.
  bool _offerClaiming = false;
  // Hard paywall only: surfaces the exit-intent offer on its own after a short
  // dwell, so undecided users see it without reaching for the close button.
  Timer? _offerTimer;
  BillingService? _billing;

  @override
  void initState() {
    super.initState();
    Telemetry.paywallReached();
    Posthog()
        .isFeatureEnabled('hard-paywall')
        .then((enabled) {
          if (!mounted) return;
          setState(() => _hardPaywall = enabled);
          // Review mode never shows the retention offer (see _inReview).
          if (enabled && !_inReview) _scheduleAutoOffer();
        })
        .catchError((_) {});
    Posthog()
        .isFeatureEnabled('inreview')
        .then((enabled) {
          if (!mounted) return;
          if (enabled) _offerTimer?.cancel(); // no retention offer in review
          setState(() => _inReview = enabled);
        })
        .catchError((_) {});
  }

  /// On a hard paywall, auto-reveal the discounted exit offer after 15s — the
  /// same popover the round X shows — so undecided users get it without having
  /// to tap close. Fires once; manual taps and dispose cancel it.
  void _scheduleAutoOffer() {
    _offerTimer?.cancel();
    _offerTimer = Timer(const Duration(seconds: 15), () {
      // Skip if we've navigated away, already converted, are mid-purchase, or
      // an offer popover is already up.
      if (!mounted ||
          _busy ||
          _inReview ||
          _offerClaiming ||
          (_billing?.isPro ?? false)) {
        return;
      }
      _showSpecialOffer();
    });
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
      // Warm the annual product so review mode can show its real store price.
      billing.loadAnnualPlan84();
    }
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _billing?.removeListener(_onBillingChange);
    super.dispose();
  }

  void _onBillingChange() {
    final billing = _billing;
    if (billing == null) return;
    if (!_wasPro && billing.isPro) {
      _wasPro = true;
      if (!_offerClaiming) widget.onPurchased();
    }
    if (mounted) setState(() {});
  }

  // Review-mode legal/restore actions.
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

  void _openLegal(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: 'LegalScreen-$title'),
        builder: (_) => LegalScreen(title: title, body: body),
      ),
    );
  }

  Future<void> _buy() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      final ok = await billing.buyAnnualPlan84();
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
            content: Text(
              'Enable notifications in Settings to get the reminder.',
            ),
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

  /// Exit-intent offer shown when the user taps the round X on a hard paywall:
  /// a popover pitching the $4.99/mo "pipmonthly" plan at 25% off. The dialog
  /// runs the purchase itself (so it stays up with a "Working…" button while the
  /// IAP sheet shows) and dismisses once Pro is granted; the paywall's billing
  /// listener then navigates away. The monthly package price comes from the
  /// already-loaded offering, so nothing extra needs warming here.
  void _showSpecialOffer() {
    // A manual tap pre-empts the auto-reveal so the popover never opens twice.
    _offerTimer?.cancel();
    final billing = _billing;
    if (billing == null) return;
    Telemetry.retentionOfferShown();
    _offerClaiming = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SpecialOfferDialog(billing: billing),
    ).then((_) => _offerClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    final annualPrice = billing?.annualPlan84PriceLabel ?? '\$83.99';
    // Normal mode bolds the weekly price. Review mode instead bolds the explicit
    // annual charge for App Store reviewers (and leaves the weekly line plain).
    final headlineSegments = _inReview
        ? <(String, bool)>[
            ('Try 3 days for free, then just \$1.62 a week!', false),
            ('\n(billed annually as $annualPrice per year)', true),
          ]
        : <(String, bool)>[
            ('Try 3 days for free, then just ', false),
            ('\$1.62 a week!', true),
            ('\n(billed annually)', false),
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
                  // Review mode always allows a plain dismiss into the app.
                  child: (_hardPaywall && !_inReview)
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
                      _PipBubble(
                        // Re-key when the copy changes (review flag flips / price
                        // resolves) so the type-out animation restarts and always
                        // reaches the end instead of freezing mid-word.
                        key: ValueKey(headlineSegments.map((s) => s.$1).join()),
                        segments: headlineSegments,
                        tailOnTop: true,
                      ),
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
              const SizedBox(height: 20),
              if (_inReview)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegalLink(
                      label: 'Privacy',
                      onTap: () => _openLegal('Privacy policy', privacyPolicyBody),
                    ),
                    const _LegalDot(),
                    _LegalLink(
                      label: 'Terms of Service',
                      onTap: () =>
                          _openLegal('Terms of service', termsOfServiceBody),
                    ),
                    const _LegalDot(),
                    _LegalLink(
                      label: 'Restore',
                      onTap: _busy ? null : _restore,
                    ),
                  ],
                )
              else
                Text(
                  'No payment due today, cancel anytime!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.ink, fontSize: 16),
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
/// No-free-trial paywall opened from a push notification: the $1.99/mo "60% off"
/// professorpipmonthlytwo offer. Mirrors [PaywallScreen] but swaps the trial
/// timeline for the onboarding lockscreen image. Buying it grants the same Pro
/// entitlement as the annual plan.
class OfferPaywallScreen extends StatefulWidget {
  const OfferPaywallScreen({super.key});

  @override
  State<OfferPaywallScreen> createState() => _OfferPaywallScreenState();
}

class _OfferPaywallScreenState extends State<OfferPaywallScreen> {
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
      // Fetch the offer's product so the bubble and button show its real store
      // price; rebuilds via _onBillingChange once it resolves.
      billing.loadPipMonthlyTwo();
    }
  }

  @override
  void dispose() {
    _billing?.removeListener(_onBillingChange);
    super.dispose();
  }

  /// Live store price for this offer, falling back to its list price until the
  /// product load resolves.
  String _priceLabel(BillingService? billing) =>
      billing?.pipMonthlyTwoPriceLabel ?? '\$1.99';

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
      final ok = await billing.buyPipMonthlyTwo();
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
    final priceLabel = _priceLabel(billing);
    final bubbleText =
        'Special offer just for you, daily vocab for just $priceLabel a month!';
    final buttonLabel = 'Unlock for $priceLabel a month';
    const subtext = '30-day money-back guarantee, cancel anytime';
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
                        const Positioned(
                          top: -6,
                          right: -6,
                          child: _DiscountBadge(percent: 60),
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
  final int percent;
  const _DiscountBadge({required this.percent});

  @override
  State<_DiscountBadge> createState() => _DiscountBadgeState();
}

class _DiscountBadgeState extends State<_DiscountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1.1,
  ).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeInOut));

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.percent}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const Text(
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
          Expanded(
            child: Text(
              'Reminder before trial ends',
              style: appText(size: 19, weight: FontWeight.w700),
            ),
          ),
          Transform.scale(
            scale: 1.15,
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
  const _PipBubble({super.key, this.text, this.segments, this.tailOnTop = false})
    : assert(
        text != null || segments != null,
        'Provide either text or segments',
      );

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
    duration: Duration(
      milliseconds: (widget.plainText.length * 60).clamp(900, 3200),
    ),
  );
  late final Animation<int> _chars = StepTween(
    begin: 0,
    end: widget.plainText.length,
  ).animate(CurvedAnimation(parent: _ctl, curve: Curves.linear));

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
      final piece = segText.length <= remaining
          ? segText
          : segText.substring(0, remaining);
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
          crossAxisAlignment: widget.tailOnTop
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
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
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      )
                    : const TextStyle(
                        color: AppColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      );
                final align = widget.tailOnTop
                    ? TextAlign.center
                    : TextAlign.start;
                final reveal = RichText(
                  textAlign: align,
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
                // Reserve the final size with an invisible copy of the full text
                // so the bubble never reflows (resizes) as it types — that resize
                // is what made the fill look jerky.
                return Stack(
                  children: [
                    Opacity(
                      opacity: 0,
                      child: RichText(
                        textAlign: align,
                        text: TextSpan(
                          style: baseStyle,
                          children: _visibleSpans(
                            widget.plainText.length,
                            baseStyle,
                          ),
                        ),
                      ),
                    ),
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
  // When true the tail points up from the top edge; otherwise left from the
  // left edge.
  final bool tailOnTop;
  const _SpeechBubblePainter({this.tailOnTop = false});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(22);
    final path = tailOnTop
        ? _topTailPath(size, radius)
        : _leftTailPath(size, radius);

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

/// A tappable legal/restore link shown under the CTA in App Store review mode.
class _LegalLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _LegalLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _LegalDot extends StatelessWidget {
  const _LegalDot();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('·', style: TextStyle(color: AppColors.muted, fontSize: 14)),
      );
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE02424),
          shape: BoxShape.circle,
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close, size: 22, color: Colors.white),
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
          color: const Color(0xFFE02424),
          shape: BoxShape.circle,
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close, size: 26, color: Colors.white),
      ),
    );
  }
}

/// Exit-intent popover offering the discounted ~$2/mo plan, fronted by a Lottie
/// gift-opening animation. Runs the purchase in place: the dialog stays up (with
/// a "Working…" button) while the StoreKit sheet shows, then dismisses once Pro
/// is granted — leaving the paywall's billing listener to navigate on. A
/// cancelled or failed purchase just resets the button and keeps the offer up.
class _SpecialOfferDialog extends StatefulWidget {
  final BillingService billing;
  const _SpecialOfferDialog({required this.billing});

  @override
  State<_SpecialOfferDialog> createState() => _SpecialOfferDialogState();
}

class _SpecialOfferDialogState extends State<_SpecialOfferDialog>
    with SingleTickerProviderStateMixin {
  bool _busy = false;

  // Drives the gift bouncing up and down in front of Professor Pip.
  late final AnimationController _bounceCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);
  late final Animation<double> _bounce = Tween<double>(begin: 6, end: -16)
      .animate(CurvedAnimation(parent: _bounceCtl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _bounceCtl.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    // buyPipMonthly swallows its own errors and returns false on cancel/failure,
    // so a try/finally isn't needed here.
    final ok = await widget.billing.buyPipMonthly();
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false); // cancelled/failed — keep the offer up
      return;
    }
    Telemetry.monthlyStarted();
    // Go straight to the app — same path the push-offer paywall uses. Persist
    // onboarding-complete (in case this was bought mid-onboarding) and replace
    // the whole stack (this dialog + the paywall) with Home.
    SharedPreferences.getInstance()
        .then((p) => p.setBool('onboarding_completed', true))
        .catchError((_) => false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: const RouteSettings(name: 'HomeScreen'),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthlyPrice = widget.billing.pipMonthlyPriceLabel ?? '\$4.99';
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 290,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Professor Pip — the centerpiece.
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Brutal.borderColor,
                            width: Brutal.borderWidth,
                          ),
                          boxShadow: Brutal.shadow(dx: 3, dy: 4),
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
                      // The gift bounding up and down at his bottom-left.
                      Positioned(
                        bottom: 0,
                        left: -75,
                        child: AnimatedBuilder(
                          animation: _bounce,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _bounce.value),
                            child: child,
                          ),
                          child: SizedBox(
                            height: 185,
                            child: Lottie.asset(
                              'assets/lottie/gift.json',
                              fit: BoxFit.contain,
                              // Falls back to the static gift image if the Lottie
                              // ever fails to load, so it never renders broken.
                              errorBuilder: (_, _, _) => Image.asset(
                                'assets/gift.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "Wait, don't leave!",
                  textAlign: TextAlign.center,
                  style: appText(
                    size: 24,
                    weight: FontWeight.w800,
                    height: 1.15,
                  ),
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
                    children: [
                      const TextSpan(text: 'Unlock '),
                      const TextSpan(
                        text: '10,000 words',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' and '),
                      const TextSpan(
                        text: '15 topics',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' for '),
                      TextSpan(
                        text: '$monthlyPrice a month',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _busy ? 'Working…' : 'Unlock Everything',
                  color: AppColors.giftRed,
                  pulse: !_busy,
                  onPressed: _busy ? null : _claim,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Billed monthly, cancel anytime!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 12,
            right: 12,
            child: _DiscountBadge(percent: 25),
          ),
        ],
      ),
    );
  }
}
