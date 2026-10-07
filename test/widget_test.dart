import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:application_smartacademicassistant/core/services/storage_service.dart';
import 'package:application_smartacademicassistant/main.dart';

void main() {
  testWidgets('App initializes without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const SmartAcademicAssistantApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(SmartAcademicAssistantApp), findsOneWidget);
  });
}
