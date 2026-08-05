import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/models/makon_user_role.dart";
import "package:makon3d_mobile/services/auth/auth_state.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

class MakonRoleSelectionScreen extends StatefulWidget {
  const MakonRoleSelectionScreen({super.key, required this.isRequired});

  final bool isRequired;

  @override
  State<MakonRoleSelectionScreen> createState() =>
      _MakonRoleSelectionScreenState();
}

class _MakonRoleSelectionScreenState extends State<MakonRoleSelectionScreen> {
  MakonUserRole? _selectedRole;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedRole = AuthState().makonRole;
  }

  Future<void> _continue() async {
    final role = _selectedRole;
    if (role == null || _saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await AuthState().setMakonRole(role);
      if (!mounted) return;
      if (!widget.isRequired && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      debugPrint("Makon role save failed: $error");
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = L10n.get("makon_role_save_failed");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isRequired,
      child: Scaffold(
        appBar: widget.isRequired
            ? null
            : AppBar(title: Text(L10n.get("settings_primary_profile"))),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 52,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        L10n.get("makon_role_choose_title"),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: MakonColors.ink,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        L10n.get("makon_role_choose_subtitle"),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: MakonColors.inkMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (final role in MakonUserRole.values) ...[
                        _RoleCard(
                          role: role,
                          selected: role == _selectedRole,
                          onTap: _saving
                              ? null
                              : () => setState(() {
                                  _selectedRole = role;
                                  _errorText = null;
                                }),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      if (_errorText != null) ...[
                        Text(
                          _errorText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _selectedRole == null || _saving
                              ? null
                              : _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: MakonColors.yellow,
                            foregroundColor: MakonColors.black,
                            disabledBackgroundColor: MakonColors.yellowSoft,
                            disabledForegroundColor: MakonColors.inkMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  L10n.get("makon_role_continue"),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final MakonUserRole role;
  final bool selected;
  final VoidCallback? onTap;

  IconData get _icon => switch (role) {
    MakonUserRole.customer => Icons.home_repair_service_outlined,
    MakonUserRole.contractor => Icons.handyman_outlined,
    MakonUserRole.supplier => Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? MakonColors.yellowSoft : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? MakonColors.ink
                  : MakonColors.ink.withValues(alpha: 0.12),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: MakonColors.yellow,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: MakonColors.black, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.get(role.titleL10nKey),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      L10n.get(role.subtitleL10nKey),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MakonColors.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? MakonColors.ink : MakonColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
