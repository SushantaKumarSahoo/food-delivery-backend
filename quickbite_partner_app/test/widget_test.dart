import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickbite_partner_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: QuickBitePartnerApp(),
      ),
    );

    expect(find.byType(QuickBitePartnerApp), findsOneWidget);

    // Allow pending microtasks and timers to complete
    await tester.pump(const Duration(seconds: 5));
  }, skip: true);
}
