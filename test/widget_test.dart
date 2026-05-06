import 'package:flutter_test/flutter_test.dart';

import 'package:vocab_genius/billing/billing_service.dart';
import 'package:vocab_genius/main.dart';
import 'package:vocab_genius/topics/topics_repository.dart';

void main() {
  testWidgets('Onboarding boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProfessorPipApp(
        topicsRepo: TopicsRepository(),
        billing: BillingService(),
      ),
    );
    expect(find.text("Nice to meet you, Pip"), findsOneWidget);
  });
}
