import 'package:flutter/material.dart';
import '../onboarding/theme.dart';
import '../onboarding/widgets.dart';
import 'billing_service.dart';

/// Shows the limited-time 40%-off offer as a bottom sheet. No-op for Pro users.
/// The CTA purchases the annual plan through RevenueCat.
Future<void> maybeShowOfferSheet(
  BuildContext context,
  BillingService billing,
) async {
  if (billing.isPro) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _OfferSheet(billing: billing),
  );
}

class _OfferSheet extends StatefulWidget {
  final BillingService billing;
  const _OfferSheet({required this.billing});

  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    final ok = await widget.billing.buyAnnual();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Professor Pip Pro! 🎉')),
      );
    } else if (widget.billing.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.billing.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.billing.annualPriceLabel;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Brutal.borderColor,
              width: Brutal.borderWidth,
            ),
            boxShadow: Brutal.shadow(dx: 4, dy: 6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 24, color: AppColors.burgundy),
                  ),
                ),
              ),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Brutal.borderColor,
                    width: Brutal.borderWidth,
                  ),
                  boxShadow: Brutal.shadow(dx: 3, dy: 4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/gift.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.burgundy,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Brutal.borderColor,
                    width: Brutal.borderWidth,
                  ),
                ),
                child: const Text(
                  'LIMITED TIME OFFER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '40% OFF',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'the Annual Plan',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                price != null
                    ? 'Just $price billed yearly — unlock every topic.'
                    : 'Unlock every topic and keep learning, for less.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _busy ? 'Working…' : 'Claim 40% Off',
                onPressed: _busy ? null : _claim,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _busy ? null : () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
