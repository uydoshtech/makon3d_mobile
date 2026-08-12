import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/main.dart";
import "package:makon3d_mobile/screens/splash_screen.dart";

void main() {
  testWidgets("Splash shows the native-matched logo without a fade", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "selected_language": "en",
    });
    await LanguageState.initialize();
    await tester.pumpWidget(const MakonixApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    // Let the splash hold and the route transition complete so the test does
    // not leave its scheduled timer behind.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
