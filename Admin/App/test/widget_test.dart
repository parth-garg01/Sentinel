import 'package:flutter_test/flutter_test.dart';

import 'package:sentinel_admin/main.dart';

void main() {
  testWidgets('admin dashboard renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SentinelAdminApp());

    expect(find.text('Assigned Cases'), findsOneWidget);
  });
}
