import "dart:async";

import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Settings tab: app language (uz / ru / en).
///
/// The whole app rebuilds on [LanguageState] changes (see `main.dart`), so a
/// stateless widget is enough here.
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              L10n.get("settings_language_title"),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MakonColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          for (final locale in supportedLocales)
            _languageTile(
              code: locale.languageCode,
              selected: locale.languageCode == current,
            ),
        ],
      ),
    );
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
