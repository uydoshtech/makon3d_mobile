import "package:flutter/material.dart";

import "package:makon3d_mobile/screens/main_shell.dart";

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
  static const _background = Color(0xFFFFFFFF);
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
    await Future<void>.delayed(const Duration(milliseconds: _holdMs));
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
      backgroundColor: _background,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Image.asset(
              "assets/branding/makon3d_logo.png",
              fit: BoxFit.contain,
              // Same logical size as the native launch screen's intrinsic
              // LaunchImage (137x160 pt) so the handoff is seamless.
              width: 137,
            ),
          ),
        ),
      ),
    );
  }
}
