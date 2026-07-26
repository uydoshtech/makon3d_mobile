import "package:flutter/foundation.dart" show defaultTargetPlatform;
import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";

/// Google sign-in control shared visually with the UyDosh login flow.
class GoogleSignInBrandedButton extends StatefulWidget {
  const GoogleSignInBrandedButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<GoogleSignInBrandedButton> createState() =>
      _GoogleSignInBrandedButtonState();
}

class _GoogleSignInBrandedButtonState extends State<GoogleSignInBrandedButton> {
  static const _height = 44.0;
  static const _iconSlotScale = 28 / 44;

  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final labelFontSize = _height * 0.43;
    final useSfPro =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      transform: Matrix4.translationValues(0, _pressed && _enabled ? 2 : 0, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF131314),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF8E918F)),
            ),
            child: SizedBox(
              height: _height,
              child: Opacity(
                opacity: _enabled ? 1 : 0.55,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: _iconSlotScale * _height,
                        height: _iconSlotScale * _height + 2,
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Center(
                          child: SizedBox(
                            width: labelFontSize,
                            height: labelFontSize,
                            child: SvgPicture.asset(
                              "assets/branding/google_g_logo.svg",
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            inherit: false,
                            color: const Color(0xFFE3E3E3),
                            fontSize: labelFontSize,
                            letterSpacing: -0.41,
                            fontFamily: useSfPro ? ".SF Pro Text" : null,
                          ),
                        ),
                      ),
                      SizedBox(width: _iconSlotScale * _height),
                    ],
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
