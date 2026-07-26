import "package:flutter/material.dart";

import "package:makon3d_mobile/screens/main_shell.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";
import "package:makon3d_mobile/services/makon_project_migration.dart";
import "package:makon3d_mobile/services/makon_project_store.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Brief branded splash before the main tab shell.
///
/// Full-screen Makon yellow with the black brand mark and wordmark centered —
/// matching the native iOS launch screen for a continuous handoff.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _holdMs = 1200;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: _holdMs)),
      if (AuthState().isSignedIn) ...[
        MakonProjectStore.instance.ensureLoaded(),
        MakonProjectMigration.runIfNeeded(),
      ],
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MainShell(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MakonColors.yellow,
      body: Center(
        child: Image.asset(
          "assets/branding/makon_splash_logo.png",
          fit: BoxFit.contain,
          // Native LaunchScreen.storyboard renders this same artwork at
          // 220pt wide. Keeping those bounds identical prevents a visual
          // jump when Flutter draws its first frame.
          width: 220,
        ),
      ),
    );
  }
}
