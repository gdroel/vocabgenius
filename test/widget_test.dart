import 'package:flutter_test/flutter_test.dart';

import 'package:vocab_genius/main.dart';
import 'package:vocab_genius/topics/topics_repository.dart';

void main() {
  testWidgets('Onboarding boots', (WidgetTester tester) async {
    await tester.pumpWidget(ProfessorPipApp(topicsRepo: TopicsRepository()));
    expect(find.text('Get started'), findsOneWidget);
  });
}
