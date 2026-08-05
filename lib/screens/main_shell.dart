import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_user_role.dart';
import 'package:makon3d_mobile/screens/contractor_jobs_feed_screen.dart';
import 'package:makon3d_mobile/screens/new_project_screen.dart';
import 'package:makon3d_mobile/screens/projects_list_screen.dart';
import 'package:makon3d_mobile/screens/scans_list_screen.dart';
import 'package:makon3d_mobile/screens/settings_screen.dart';
import 'package:makon3d_mobile/services/auth/auth_state.dart';
import 'package:makon3d_mobile/widgets/curved_nav_bar.dart';
import 'package:makon3d_mobile/widgets/sign_in_sheet.dart';

/// Three-tab shell: Projects + legacy device scans list + settings.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const int _projectsTab = 0;
  static const int _scansListTab = 1;
  static const int _settingsTab = 2;

  @override
  void initState() {
    super.initState();
    AuthState().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthState().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  void _goToTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  Future<void> _openNewProject() async {
    if (!AuthState().isSignedIn) {
      await SignInSheet.show(context);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NewProjectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onProjects = _index == _projectsTab;
    final isContractor = AuthState().makonRole == MakonUserRole.contractor;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          if (isContractor)
            ContractorJobsFeedScreen(
              onOpenAccount: () => _goToTab(_settingsTab),
            )
          else
            ProjectsListScreen(
              isActive: onProjects,
              onCreateProject: () => unawaited(_openNewProject()),
              onOpenAccount: () => _goToTab(_settingsTab),
            ),
          ScansListScreen(isActive: _index == _scansListTab),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton:
          onProjects && AuthState().isSignedIn && !isContractor
          ? FloatingActionButton(
              onPressed: () => unawaited(_openNewProject()),
              tooltip: L10n.get('project_new_title'),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: MakonCurvedNavBar(
        currentIndex: _index,
        onTap: _goToTab,
        firstLabelKey: isContractor ? 'nav_jobs' : 'nav_projects',
        firstIcon: isContractor ? Icons.work_outline : Icons.folder_outlined,
      ),
    );
  }
}
