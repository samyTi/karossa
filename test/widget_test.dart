import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage_auto/app.dart';

void main() {
  testWidgets('GarageApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: GarageApp()));

    // Verify that the app builds successfully
    expect(find.text('Garage Auto'), findsOneWidget);
  });
}