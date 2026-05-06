import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../onboarding/theme.dart';
import 'billing_service.dart';
import 'legal_screen.dart';
import 'paywall_screen.dart';

const _manageSubsUrl = 'https://apps.apple.com/account/subscriptions';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  BillingService? _billing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final billing = BillingScope.of(context);
    if (!identical(billing, _billing)) {
      _billing?.removeListener(_onBillingChange);
      _billing = billing;
      billing.addListener(_onBillingChange);
    }
  }

  @override
  void dispose() {
    _billing?.removeListener(_onBillingChange);
    super.dispose();
  }

  void _onBillingChange() {
    if (mounted) setState(() {});
  }

  Future<void> _restore() async {
    final billing = _billing;
    if (billing == null) return;
    setState(() => _busy = true);
    try {
      await billing.restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            billing.isPro
                ? 'Subscription restored'
                : 'No active subscription found',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(
          onDismiss: () => Navigator.of(context).pop(),
          onPurchased: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = _billing;
    final isPro = billing?.isPro ?? false;
    final price = billing?.annualProduct?.price ?? '\$24.99/year';
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SubscriptionCard(
                      isPro: isPro,
                      priceLabel: price,
                      onSubscribe: _openPaywall,
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel(text: 'Subscription'),
                    _AccountRow(
                      icon: Icons.refresh_rounded,
                      label: 'Restore purchases',
                      busy: _busy,
                      onTap: _busy ? null : _restore,
                    ),
                    const SizedBox(height: 10),
                    _AccountRow(
                      icon: Icons.settings_rounded,
                      label: 'Manage subscription',
                      onTap: () => _openUrl(_manageSubsUrl),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel(text: 'Legal'),
                    _AccountRow(
                      icon: Icons.gavel_rounded,
                      label: 'Terms of service',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalScreen(
                            title: 'Terms of service',
                            body: termsOfServiceBody,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AccountRow(
                      icon: Icons.shield_outlined,
                      label: 'Privacy policy',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalScreen(
                            title: 'Privacy policy',
                            body: privacyPolicyBody,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Brutal.borderColor,
                  width: Brutal.borderWidth,
                ),
                boxShadow: Brutal.shadow(dx: 2, dy: 3),
              ),
              child: const Icon(Icons.close, color: AppColors.ink),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Account',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final bool isPro;
  final String priceLabel;
  final VoidCallback onSubscribe;
  const _SubscriptionCard({
    required this.isPro,
    required this.priceLabel,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Brutal.borderColor,
          width: Brutal.borderWidth,
        ),
        boxShadow: Brutal.shadow(dx: 4, dy: 5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_outline_rounded,
                color: AppColors.burgundy,
              ),
              const SizedBox(width: 10),
              Text(
                isPro ? 'Pip Annual — Active' : 'Free plan',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPro
                ? '$priceLabel · auto-renews yearly. Cancel anytime in iOS Settings.'
                : '3-day free trial, then $priceLabel · auto-renews yearly. Cancel anytime.',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (!isPro) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onSubscribe,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.burgundy,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Brutal.borderColor,
                    width: Brutal.borderWidth,
                  ),
                  boxShadow: Brutal.shadow(dx: 2, dy: 3),
                ),
                child: const Text(
                  'Start free trial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Brutal.borderColor,
            width: Brutal.borderWidth,
          ),
          boxShadow: Brutal.shadow(dx: 2, dy: 3),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.ink, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: onTap == null ? AppColors.muted : AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.muted,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
