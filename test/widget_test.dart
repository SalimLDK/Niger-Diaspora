import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diaspo_niger/app.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NigerDiasporaApp(),
      ),
    );

    // Verify that the app builds
    expect(find.byType(NigerDiasporaApp), findsOneWidget);
  });
}
