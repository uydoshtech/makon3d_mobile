import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";

import "package:makon3d_mobile/screens/main_shell.dart";
import "package:makon3d_mobile/services/makon_project_migration.dart";
import "package:makon3d_mobile/services/makon_project_store.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Brief branded splash before the main tab shell.
///
/// Matches the native iOS launch screen (white + centered logo) so the
/// handoff from LaunchScreen.storyboard feels continuous.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _holdMs = 1200;

  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _run();
  }

  Future<void> _run() async {
    await _fadeController.forward();
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: _holdMs)),
      MakonProjectStore.instance.ensureLoaded(),
      MakonProjectMigration.runIfNeeded(),
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
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  "assets/branding/makon3d_mark.svg",
                  fit: BoxFit.contain,
                  width: 140,
                ),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                    children: const [
                      TextSpan(
                        text: "Makon",
                        style: TextStyle(color: MakonColors.slateMuted),
                      ),
                      TextSpan(
                        text: "3D",
                        style: TextStyle(color: MakonColors.teal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
