import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/main.dart";

void main() {
  testWidgets("Shell shows scan tab and curved nav", (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "selected_language": "en",
    });
    await LanguageState.initialize();
    await tester.pumpWidget(const Makon3DApp());
    await tester.pump();

    expect(find.text("3D room scan"), findsOneWidget);
    expect(find.text("Scans"), findsOneWidget);
  });
}
