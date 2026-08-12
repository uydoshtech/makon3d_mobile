import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/screens/splash_screen.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";
import "package:makon3d_mobile/services/auth/firebase_bootstrap.dart";
import "package:makon3d_mobile/theme/makon_theme.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageState.initialize();
  await FirebaseBootstrap.initialize();
  await AuthState.initialize();
  runApp(const MakonixApp());
}

class MakonixApp extends StatelessWidget {
  const MakonixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageState(),
      builder: (context, _) {
        return MaterialApp(
          title: "Makonix",
          debugShowCheckedModeBanner: false,
          locale: Locale(LanguageState().currentLanguage),
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildMakonTheme(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
