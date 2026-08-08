import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/theme/makon_theme.dart";
import "package:makon3d_mobile/widgets/detected_objects_section.dart";

void main() {
  testWidgets("shows detected object names and counts expanded", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "selected_language": "ru",
    });
    await LanguageState.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMakonTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: DetectedObjectsSection(
              initiallyExpanded: true,
              counts: <String, int>{
                "window": 3,
                "storage": 2,
                "sofa": 1,
                "table": 1,
                "chair": 2,
                "door": 0,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("detected_objects_section")), findsOneWidget);
    expect(find.text("Обнаруженные объекты"), findsOneWidget);
    expect(find.text("Окна"), findsOneWidget);
    expect(find.text("Хранилище"), findsOneWidget);
    expect(find.text("Диваны"), findsOneWidget);
    expect(find.text("Столы"), findsOneWidget);
    expect(find.text("Стулья"), findsOneWidget);
    expect(find.text("Двери"), findsNothing);
    expect(find.text("× 3"), findsOneWidget);
    expect(find.text("× 2"), findsNWidgets(2));
    expect(find.byIcon(Icons.window_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(find.byIcon(Icons.weekend_outlined), findsOneWidget);
    expect(find.byIcon(Icons.table_restaurant_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chair_outlined), findsOneWidget);
  });
}
