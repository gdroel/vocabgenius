import 'package:flutter/material.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../notifications/notifications_service.dart';
import '../onboarding/theme.dart';
import '../onboarding/widgets.dart';
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
      await billing.buyAnnual();
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: _hardPaywall
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _CloseButton(onTap: widget.onDismiss),
                      ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
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
              ),
              const SizedBox(height: 16),
              Text(
                'Enjoy your free trial',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              const _Timeline(),
              const SizedBox(height: 16),
              _ReminderToggle(
                value: _reminderBeforeTrialEnds,
                onChanged: _onReminderToggle,
              ),
              const Spacer(),
              if (billing?.lastError != null && !(billing?.isPro ?? false))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    billing!.lastError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.burgundy,
                      fontSize: 12,
                    ),
                  ),
                ),
              PrimaryButton(
                label: _busy ? 'Working…' : 'Try for \$0.00',
                onPressed: _busy ? null : _buy,
              ),
              const SizedBox(height: 10),
              const Text(
                'Then \$59.99/yr (\$5 a month)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _busy ? null : _restore,
                child: const Text(
                  'Privacy   Terms & Conditions   Restore',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline();

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
      ('${_fmt(reminder)} - Trial reminder', "We'll remind you before it ends", Icons.notifications_active_rounded),
      ('${_fmt(billing)} - Become member', 'Trial ends and full plan begins for \$59.99 (\$5 a month)', Icons.workspace_premium_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
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
          for (int i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i < 2 ? AppColors.success : AppColors.creamSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        items[i].$3,
                        size: 14,
                        color: i < 2 ? Colors.white : AppColors.muted,
                      ),
                    ),
                    if (i < items.length - 1)
                      Container(
                        width: 2,
                        height: 36,
                        color: i < 1 ? AppColors.success : AppColors.creamSoft,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$1,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$2,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
              style: TextStyle(color: AppColors.ink, fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.teal,
          ),
        ],
      ),
    );
  }
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
        child: Icon(Icons.close, size: 18, color: AppColors.burgundy),
      ),
    );
  }
}
