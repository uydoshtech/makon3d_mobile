import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/screens/new_project_screen.dart';
import 'package:makon3d_mobile/screens/projects_list_screen.dart';
import 'package:makon3d_mobile/screens/scans_list_screen.dart';
import 'package:makon3d_mobile/widgets/curved_nav_bar.dart';

/// Two-tab shell: Projects + legacy device scans list.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const int _projectsTab = 0;
  static const int _scansListTab = 1;

  void _goToTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  Future<void> _openNewProject() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NewProjectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onProjects = _index == _projectsTab;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          ProjectsListScreen(
            isActive: onProjects,
            onCreateProject: () => unawaited(_openNewProject()),
          ),
          ScansListScreen(isActive: _index == _scansListTab),
        ],
      ),
      floatingActionButton: onProjects
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
      ),
    );
  }
}
