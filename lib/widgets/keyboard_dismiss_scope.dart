import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';

/// Soft-keyboard dismiss helpers for screens with text / number fields.
///
/// Number pads have no return key, so without this the keyboard stays up.
/// Provides tap-outside dismiss, optional Done bar, and a scroll-dismiss
/// constant for enclosed scroll views.
class KeyboardDismissScope extends StatefulWidget {
  const KeyboardDismissScope({
    required this.child,
    super.key,
    this.dismissOnTapOutside = true,
    this.showDoneBar = true,
  });

  static const ScrollViewKeyboardDismissBehavior scrollBehavior =
      ScrollViewKeyboardDismissBehavior.onDrag;

  final Widget child;
  final bool dismissOnTapOutside;
  final bool showDoneBar;

  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  State<KeyboardDismissScope> createState() => _KeyboardDismissScopeState();
}

class _KeyboardDismissScopeState extends State<KeyboardDismissScope>
    with WidgetsBindingObserver {
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBarVisibility());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _syncBarVisibility();
  }

  @override
  void didUpdateWidget(covariant KeyboardDismissScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showDoneBar != widget.showDoneBar) {
      _syncBarVisibility();
    }
  }

  void _syncBarVisibility() {
    if (!mounted) return;
    final rawKeyboardInset = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;
    final shouldShow = rawKeyboardInset > 0 && widget.showDoneBar;
    if (shouldShow && !_portalController.isShowing) {
      _portalController.show();
    } else if (!shouldShow && _portalController.isShowing) {
      _portalController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tapCatcher = widget.dismissOnTapOutside
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: KeyboardDismissScope.dismiss,
            child: widget.child,
          )
        : widget.child;

    if (!widget.showDoneBar) return tapCatcher;

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: _buildDoneBar,
      child: tapCatcher,
    );
  }

  Widget _buildDoneBar(BuildContext overlayContext) {
    final mq = MediaQuery.of(overlayContext);
    final scheme = Theme.of(overlayContext).colorScheme;
    final isDark = Theme.of(overlayContext).brightness == Brightness.dark;

    return Positioned(
      left: 0,
      right: 0,
      bottom: mq.viewInsets.bottom,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.4 : 0.6,
                ),
                width: 0.5,
              ),
            ),
          ),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: KeyboardDismissScope.dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    minimumSize: const Size(64, 36),
                  ),
                  child: Text(L10n.get('done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
