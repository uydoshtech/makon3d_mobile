import "package:curved_navigation_bar/curved_navigation_bar.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:makon3d_mobile/screens/scan_screen.dart";
import "package:makon3d_mobile/screens/scans_list_screen.dart";
import "package:makon3d_mobile/widgets/curved_nav_bar.dart";

/// Two-tab shell: Scan + list of this device's scans.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<CurvedNavigationBarState> _navKey =
      GlobalKey<CurvedNavigationBarState>();
  int _index = 0;

  static const int _scansListTab = 1;

  void _goToTab(int index) {
    if (index == _index) return;
    HapticFeedback.selectionClick();
    // Keep the curved bar animation in sync when switching programmatically.
    _navKey.currentState?.setPage(index);
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let content sit under the curved notch (same as UyDosh main shell).
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          ScanScreen(
            onScanUploaded: () => _goToTab(_scansListTab),
          ),
          ScansListScreen(isActive: _index == _scansListTab),
        ],
      ),
      bottomNavigationBar: MakonCurvedNavBar(
        currentIndex: _index,
        navigationKey: _navKey,
        onTap: _goToTab,
      ),
    );
  }
}
