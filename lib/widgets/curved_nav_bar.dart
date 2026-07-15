import "package:curved_navigation_bar/curved_navigation_bar.dart";
import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";

/// Slim 2-tab curved bottom bar (Scan / Scans), matching UyDosh's look via
/// [curved_navigation_bar] + a neumorphic active orb — without auth/gig coupling.
class MakonCurvedNavBar extends StatelessWidget {
  const MakonCurvedNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color _barColor = Color(0xFF4B3A2F);
  static const Color _orbColor = Color(0xFF6D5647);
  static const Color _notchColor = Color(0xFF3A2C23);
  static const Color _labelColor = Color(0xFFF5F0EB);

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _navItem(
        icon: Icons.view_in_ar,
        labelKey: "nav_scan",
        selected: currentIndex == 0,
      ),
      _navItem(
        icon: Icons.view_list_rounded,
        labelKey: "nav_scans",
        selected: currentIndex == 1,
      ),
    ];

    return SizedBox(
      height: 70,
      child: CurvedNavigationBar(
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
  }

  Widget _navItem({
    required IconData icon,
    required String labelKey,
    required bool selected,
  }) {
    final iconWidget = Icon(
      icon,
      size: 26,
      color: _labelColor,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          _ActiveOrb(child: iconWidget)
        else
          iconWidget,
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
                      Color.lerp(MakonCurvedNavBar._orbColor, Colors.white, 0.18)!,
                      MakonCurvedNavBar._orbColor,
                      Color.lerp(MakonCurvedNavBar._orbColor, Colors.black, 0.35)!,
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
