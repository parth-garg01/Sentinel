import 'package:flutter_test/flutter_test.dart';

import 'package:sentinal/main.dart';

void main() {
  testWidgets('calculator disguise renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SentinelApp());

    expect(find.text('0'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
  });
}
