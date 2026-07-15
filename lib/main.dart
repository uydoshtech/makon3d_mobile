import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/screens/scan_screen.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageState.initialize();
  runApp(const Makon3DApp());
}

class Makon3DApp extends StatelessWidget {
  const Makon3DApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageState(),
      builder: (context, _) {
        return MaterialApp(
          title: "Makon 3D",
          debugShowCheckedModeBanner: false,
          locale: Locale(LanguageState().currentLanguage),
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4B3A2F)),
          ),
          home: const ScanScreen(),
        );
      },
    );
  }
}
