import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noma/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: NomaApp()));
    expect(find.byType(NomaApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
