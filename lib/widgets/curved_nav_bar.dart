import "package:curved_navigation_bar/curved_navigation_bar.dart";
import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Slim 3-tab curved bottom bar (Projects / Scans / Settings) in Makon brand
/// black/yellow.
class MakonCurvedNavBar extends StatelessWidget {
  const MakonCurvedNavBar({
    required this.currentIndex,
    required this.onTap,
    this.firstLabelKey = "nav_projects",
    this.firstIcon = Icons.folder_outlined,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final String firstLabelKey;
  final IconData firstIcon;

  static const Color _barColor = MakonColors.inkElevated;
  static const Color _orbColor = MakonColors.yellow;
  static const Color _notchColor = MakonColors.ink;
  static const Color _labelColor = MakonColors.onDark;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageState(),
      builder: (context, _) {
        final items = <Widget>[
          _navItem(
            icon: firstIcon,
            labelKey: firstLabelKey,
            selected: currentIndex == 0,
          ),
          _navItem(
            icon: Icons.view_list_rounded,
            labelKey: "nav_scans",
            selected: currentIndex == 1,
          ),
          _navItem(
            icon: Icons.settings_outlined,
            labelKey: "nav_settings",
            selected: currentIndex == 2,
          ),
        ];

        // The package caches its `items` in State, so a locale-specific key
        // is required to discard the English labels it mounted with.
        return SizedBox(
          height: 70,
          child: CurvedNavigationBar(
            key: ValueKey(LanguageState().currentLanguage),
            index: currentIndex.clamp(0, items.length - 1),
            height: 70,
            color: _barColor,
            buttonBackgroundColor: Colors.transparent,
            backgroundColor: _notchColor,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 300),
            onTap: onTap,
            items: items,
          ),
        );
      },
    );
  }

  Widget _navItem({
    required IconData icon,
    required String labelKey,
    required bool selected,
  }) {
    // Selected icon sits on the yellow orb, so it flips to brand black.
    final iconWidget = Icon(
      icon,
      size: 26,
      color: selected ? MakonColors.black : _labelColor,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) _ActiveOrb(child: iconWidget) else iconWidget,
        if (!selected) ...[
          const SizedBox(height: 2),
          Text(
            L10n.get(labelKey),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _labelColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveOrb extends StatelessWidget {
  const _ActiveOrb({required this.child});

  final Widget child;

  static const double _diameter = 44;
  static const double _nudgeY = 10;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, _nudgeY),
      child: SizedBox(
        width: _diameter,
        height: _diameter,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        MakonCurvedNavBar._orbColor,
                        Colors.white,
                        0.18,
                      )!,
                      MakonCurvedNavBar._orbColor,
                      Color.lerp(
                        MakonCurvedNavBar._orbColor,
                        Colors.black,
                        0.35,
                      )!,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.55, -0.62),
                    radius: 1.05,
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.28, 0.52],
                  ),
                ),
              ),
            ),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}
