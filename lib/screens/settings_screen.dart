import "dart:async";

import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";
import "package:makon3d_mobile/widgets/sign_in_sheet.dart";

/// Settings tab: account (sign in / sign out) and app language (uz / ru / en).
///
/// The whole app rebuilds on [LanguageState] changes (see `main.dart`); the
/// account section additionally listens to [AuthState].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Language names shown in their own language (never translated).
  static const Map<String, String> _nativeNames = {
    "uz": "O'zbekcha",
    "ru": "Русский",
    "en": "English",
  };

  @override
  Widget build(BuildContext context) {
    final current = LanguageState().currentLanguage;
    return Scaffold(
      appBar: AppBar(title: Text(L10n.get("settings_title"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          _sectionHeader(context, L10n.get("settings_account_title")),
          ListenableBuilder(
            listenable: AuthState(),
            builder: (context, _) => _accountSection(context),
          ),
          _sectionHeader(context, L10n.get("settings_language_title")),
          for (final locale in supportedLocales)
            _languageTile(
              code: locale.languageCode,
              selected: locale.languageCode == current,
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: MakonColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _accountSection(BuildContext context) {
    final auth = AuthState();
    if (!auth.isSignedIn) {
      return ListTile(
        leading: const Icon(Icons.person_outline, color: MakonColors.inkMuted),
        title: Text(L10n.get("settings_sign_in")),
        trailing: const Icon(Icons.chevron_right, color: MakonColors.inkMuted),
        onTap: () => unawaited(SignInSheet.show(context)),
      );
    }

    final title = auth.displayName?.trim().isNotEmpty == true
        ? auth.displayName!
        : (auth.email?.trim().isNotEmpty == true
            ? auth.email!
            : L10n.get("settings_account_title"));
    final subtitle =
        auth.displayName?.trim().isNotEmpty == true ? auth.email : null;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person, color: MakonColors.yellow),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: MakonColors.inkMuted),
          title: Text(L10n.get("settings_sign_out")),
          onTap: () => unawaited(_confirmSignOut(context)),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.get("sign_out_confirm_title")),
        content: Text(L10n.get("sign_out_confirm_message")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10n.get("cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(L10n.get("settings_sign_out")),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthState().signOut();
    }
  }

  Widget _languageTile({required String code, required bool selected}) {
    return ListTile(
      leading: Icon(
        Icons.language,
        color: selected ? MakonColors.yellow : MakonColors.inkMuted,
      ),
      title: Text(_nativeNames[code] ?? code),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: MakonColors.yellow)
          : null,
      selected: selected,
      onTap: () => unawaited(LanguageState().setLanguage(code)),
    );
  }
}
