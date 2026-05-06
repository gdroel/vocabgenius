import 'package:flutter/material.dart';
import '../onboarding/theme.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: title),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Brutal.borderColor,
                      width: Brutal.borderWidth,
                    ),
                    boxShadow: Brutal.shadow(dx: 4, dy: 5),
                  ),
                  child: SingleChildScrollView(
                    child: _LegalBody(body: body),
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

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

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
              child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
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

class _LegalBody extends StatelessWidget {
  final String body;
  const _LegalBody({required this.body});

  @override
  Widget build(BuildContext context) {
    final blocks = body.trim().split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ..._renderBlock(block),
      ],
    );
  }

  List<Widget> _renderBlock(String block) {
    if (block.startsWith('## ')) {
      return [
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            block.substring(3).trim(),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ];
    }
    if (block.startsWith('# ')) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.substring(2).trim(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          block.trim(),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];
  }
}

const termsOfServiceBody = '''
# Last updated May 6, 2026

Welcome to Professor Pip ("the App"). These Terms of Service ("Terms") govern your use of the App and any related services we provide. By installing or using the App, you agree to these Terms. If you do not agree, please do not use the App.

## 1. The service

Professor Pip is a vocabulary-learning app that surfaces curated words across a range of topics, including a lock-screen widget that rotates a new word each hour. The App is provided on an as-is basis. We may add, change, or remove features at any time without notice.

## 2. Eligibility

You must be at least 13 years old, or the minimum age of digital consent in your jurisdiction, to use the App. By using the App you confirm that you meet this requirement.

## 3. Subscription, billing, and free trial

Some features require a paid subscription ("Pip Annual"). Subscriptions are sold as auto-renewable in-app purchases through your Apple ID account.

Payment is charged to your Apple ID at confirmation of purchase. The annual subscription renews automatically at the end of each billing period at the then-current price unless you cancel at least 24 hours before the period ends. You can manage and cancel your subscription at any time from Settings → Apple ID → Subscriptions on your device.

If a free trial is offered, any unused portion is forfeited the moment you start a paid subscription. We do not control the trial length, pricing, or refund policy — those are governed by Apple's App Store terms.

## 4. Acceptable use

You agree not to: reverse engineer or tamper with the App; use the App to harass others; attempt to bypass the subscription paywall; or use the App in any way that violates applicable law.

## 5. Content

All vocabulary content, example sentences, illustrations, and the Professor Pip character are the property of the App's owners and are protected by copyright. You may use the content for personal, non-commercial learning. You may not republish or redistribute it.

## 6. Disclaimers

The App is provided "as is" without warranties of any kind. We do not guarantee that definitions, example sentences, or any other content are free from errors, and we are not responsible for outcomes that result from relying on them.

## 7. Limitation of liability

To the maximum extent permitted by law, the App's owners are not liable for indirect, incidental, or consequential damages arising from your use of the App. Our total liability is limited to the amount you paid for your subscription in the twelve months preceding the claim.

## 8. Changes

We may update these Terms from time to time. If we make material changes we will notify you in the App. Continued use after changes take effect means you accept the updated Terms.

## 9. Termination

We may suspend or terminate your access to the App if you breach these Terms. You may stop using the App at any time by uninstalling it and canceling any active subscription through Apple.

## 10. Contact

Questions about these Terms can be sent to support@professorpip.app.
''';

const privacyPolicyBody = '''
# Last updated May 6, 2026

This Privacy Policy explains what information Professor Pip ("the App") collects, how we use it, and the choices you have. We try to collect as little as possible.

## 1. Information stored on your device

The App stores the following on your device only:

- The topics you choose to follow
- Whether you've completed onboarding
- Whether you have an active subscription (cached locally for fast launch)
- A small set of preferences such as your name and reminder settings entered during onboarding

This data lives in your iOS app sandbox and a shared App Group used by the lock-screen widget. It is not transmitted to us.

## 2. In-app purchases

When you subscribe, the purchase is handled by Apple's StoreKit. Apple, not Professor Pip, processes your payment and stores your billing details. We receive only the receipt needed to verify that your subscription is active. We do not see your full Apple ID, payment method, or address.

## 3. Lock-screen widget

The lock-screen widget reads your followed-topic list from the shared App Group on your device to pick a word to display. It does not transmit anything off the device.

## 4. Information we do not collect

The App does not contain third-party advertising or analytics SDKs. We do not collect your contacts, photos, location, microphone input, or browsing history.

## 5. Children

The App is not directed at children under 13 and we do not knowingly collect personal information from them. If you believe a child has provided personal information to the App, contact us and we will delete it.

## 6. Your rights

Because the data lives on your device, you control it. You can clear all stored data by deleting the App. To stop charges for an active subscription, cancel it from Settings → Apple ID → Subscriptions.

## 7. Changes to this policy

If we make material changes to this Privacy Policy we will notify you in the App and update the date at the top.

## 8. Contact

Questions or requests can be sent to privacy@professorpip.app.
''';
