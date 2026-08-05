import "package:flutter/material.dart";

import "package:makon3d_mobile/screens/main_shell.dart";
import "package:makon3d_mobile/screens/makon_role_selection_screen.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";

/// Keeps signed-in users in onboarding until their Makon role is selected.
class MakonRoleGate extends StatelessWidget {
  const MakonRoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthState(),
      builder: (context, _) {
        final auth = AuthState();
        if (auth.isSignedIn && auth.makonRole == null) {
          return const MakonRoleSelectionScreen(isRequired: true);
        }
        return const MainShell();
      },
    );
  }
}
