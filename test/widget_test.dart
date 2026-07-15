import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/main.dart";
import "package:makon3d_mobile/screens/splash_screen.dart";

void main() {
  testWidgets("Splash shows logo then shell with scan tab", (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "selected_language": "en",
    });
    await LanguageState.initialize();
    await tester.pumpWidget(const Makon3DApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                "assets/branding/makon3d_logo.png",
      ),
      findsOneWidget,
    );

    // Fade-in (450ms) + hold (1200ms) + route fade (350ms).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text("3D room scan"), findsOneWidget);
    expect(find.text("Scans"), findsOneWidget);
  });
}
