import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/screens/makon_role_selection_screen.dart";
import "package:makon3d_mobile/theme/makon_theme.dart";

void main() {
  testWidgets("requires one of the three Makon roles before continuing", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "selected_language": "ru",
    });
    await LanguageState.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMakonTheme(),
        home: const MakonRoleSelectionScreen(isRequired: true),
      ),
    );

    expect(find.text("Заказываю ремонт"), findsOneWidget);
    expect(find.text("Выполняю ремонт"), findsOneWidget);
    expect(find.text("Продаю материалы"), findsOneWidget);

    FilledButton continueButton = tester.widget(
      find.widgetWithText(FilledButton, "Продолжить"),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text("Заказываю ремонт"));
    await tester.pump();

    continueButton = tester.widget(
      find.widgetWithText(FilledButton, "Продолжить"),
    );
    expect(continueButton.onPressed, isNotNull);
  });
}
