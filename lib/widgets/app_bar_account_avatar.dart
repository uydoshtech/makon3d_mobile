import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Current user's circular photo/initial for an app-bar action.
///
/// The photo is persisted with the local session after Google/Apple sign-in;
/// users without one (including most Apple and Telegram accounts) see their
/// first name/email initial instead.
class AppBarAccountAvatar extends StatelessWidget {
  const AppBarAccountAvatar({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthState(),
      builder: (context, _) {
        final auth = AuthState();
        if (!auth.isSignedIn) return const SizedBox.shrink();

        final photoUrl = auth.avatarUrl?.trim();
        final initial = _initialFor(auth.displayName, auth.email);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            button: true,
            label: L10n.get("settings_account_title"),
            child: InkResponse(
              onTap: onTap,
              radius: 24,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: MakonColors.yellow,
                foregroundImage: photoUrl == null || photoUrl.isEmpty
                    ? null
                    : NetworkImage(photoUrl),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: MakonColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _initialFor(String? displayName, String? email) {
    final source =
        (displayName?.trim().isNotEmpty == true ? displayName : email)?.trim();
    if (source == null || source.isEmpty) return "?";
    return source.characters.first.toUpperCase();
  }
}
