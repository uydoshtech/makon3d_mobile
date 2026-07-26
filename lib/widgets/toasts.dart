import "dart:async";

import "package:flutter/material.dart";

/// Top-positioned toast helpers (success / error / info).
///
/// A single overlay is shared across the app so a new message replaces the
/// previous one instead of stacking banners or appearing above the tab bar.
abstract final class Toasts {
  static OverlayEntry? _currentToast;

  static void showSuccess(BuildContext context, String message) => _show(
    context,
    message,
    const Color(0xFF2E7D32),
    Icons.check_circle_outline,
  );

  static void showError(BuildContext context, String message) =>
      _show(context, message, const Color(0xFFC62828), Icons.error_outline);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, const Color(0xFF37474F), Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    if (!context.mounted) return;
    _dismissCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopToast(
        message: message,
        color: color,
        icon: icon,
        onDismiss: () {
          if (_currentToast == entry) _currentToast = null;
          entry.remove();
        },
      ),
    );
    _currentToast = entry;
    overlay.insert(entry);
  }

  static void _dismissCurrent() {
    _currentToast?.remove();
    _currentToast = null;
  }
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.message,
    required this.color,
    required this.icon,
    required this.onDismiss,
  });

  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDismiss;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 220);
  static const _displayDuration = Duration(seconds: 3);

  late final AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animationDuration)
      ..forward();
    _dismissTimer = Timer(_displayDuration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final foreground =
        ThemeData.estimateBrightnessForColor(widget.color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Positioned.fill(
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, -1.2),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(
                opacity: _controller,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Material(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: foreground),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
