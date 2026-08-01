import 'package:flutter_test/flutter_test.dart';
import 'package:noma/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NomaApp());
    expect(find.byType(NomaApp), findsOneWidget);
  });
}
