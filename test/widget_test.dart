import 'package:flutter_test/flutter_test.dart';

import 'package:vocab_genius/billing/billing_service.dart';
import 'package:vocab_genius/bookmarks/bookmarks_repository.dart';
import 'package:vocab_genius/main.dart';
import 'package:vocab_genius/topics/topics_repository.dart';

void main() {
  testWidgets('Onboarding boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProfessorPipApp(
        topicsRepo: TopicsRepository(),
        billing: BillingService(),
        bookmarks: BookmarksRepository(),
        onboardingStep: 0,
        onboardingCompleted: false,
      ),
    );
    // The welcome CTA renders on the first frame, but the intro bubble waits
    // ~350ms before starting its typewriter animation. Advance past that delay
    // and settle the animation so no pending Timer trips the test teardown.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text("Nice to meet you, Pip"), findsOneWidget);
  });
}
