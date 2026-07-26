import "package:flutter/material.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/auth/apple_auth_service.dart";
import "package:makon3d_mobile/services/auth/firebase_bootstrap.dart";
import "package:makon3d_mobile/services/auth/sign_in_flow.dart";
import "package:makon3d_mobile/services/auth/telegram_native_login_service.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";
import "package:makon3d_mobile/widgets/google_sign_in_branded_button.dart";

/// Bottom sheet with the available sign-in providers. Pops with `true`
/// after a successful sign-in ([AuthState] listeners drive the rest of the
/// UI), `null` on dismissal.
class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SignInSheet(),
    );
  }

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  bool _busy = false;
  String? _errorText;

  bool get _firebaseProvidersAvailable => FirebaseBootstrap.isReady;
  bool get _telegramAvailable =>
      TelegramNativeLoginService.instance.isSupported;

  Future<void> _run(Future<bool> Function() flow) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final signedIn = await flow();
      if (!mounted) return;
      if (signedIn) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _busy = false); // cancelled — keep the sheet open
    } catch (e) {
      debugPrint("Sign-in failed: $e");
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = L10n.get("sign_in_failed");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showApple =
        _firebaseProvidersAvailable && AppleAuthService.isAvailable;
    final showGoogle = _firebaseProvidersAvailable;
    final showTelegram = _telegramAvailable;
    final nothingAvailable = !showApple && !showGoogle && !showTelegram;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L10n.get("sign_in_sheet_title"),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            if (nothingAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  L10n.get("sign_in_unavailable"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: MakonColors.inkMuted),
                ),
              ),
            if (showApple) ...[
              SizedBox(
                height: 48,
                child: SignInWithAppleButton(
                  text: L10n.get("sign_in_with_apple"),
                  onPressed: _busy
                      ? () {}
                      : () => _run(SignInFlow.signInWithApple),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (showGoogle) ...[
              GoogleSignInBrandedButton(
                label: L10n.get("sign_in_with_google"),
                onPressed: _busy
                    ? null
                    : () => _run(SignInFlow.signInWithGoogle),
              ),
              const SizedBox(height: 12),
            ],
            if (showTelegram) ...[
              _providerButton(
                label: L10n.get("sign_in_with_telegram"),
                icon: Icons.send_rounded,
                onPressed: () => _run(SignInFlow.signInWithTelegram),
              ),
              const SizedBox(height: 12),
            ],
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _providerButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: MakonColors.ink,
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
