import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const int _scansListTab = 1;

  void _goToTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          ProjectsListScreen(isActive: _index == 0),
          ScansListScreen(isActive: _index == _scansListTab),
        ],
      ),
      bottomNavigationBar: MakonCurvedNavBar(
        currentIndex: _index,
        onTap: _goToTab,
      ),
    );
  }
}
