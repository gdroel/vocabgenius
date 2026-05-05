import 'package:flutter_test/flutter_test.dart';

import 'package:vocab_genius/main.dart';

void main() {
  testWidgets('Onboarding boots', (WidgetTester tester) async {
    await tester.pumpWidget(const VocabGeniusApp());
    expect(find.text('Get started'), findsOneWidget);
  });
}
