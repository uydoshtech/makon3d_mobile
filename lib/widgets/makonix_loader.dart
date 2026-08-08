import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';

/// Spinning Makonix mark for page-level and other spacious loading states.
/// Compact indicators inside buttons and form controls should stay standard.
class MakonixLoader extends StatefulWidget {
  const MakonixLoader({this.size = 48, this.color, super.key});

  final double size;
  final Color? color;

  @override
  State<MakonixLoader> createState() => _MakonixLoaderState();
}

class _MakonixLoaderState extends State<MakonixLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: L10n.get('loading'),
      liveRegion: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: RotationTransition(
            turns: _controller,
            child: SvgPicture.asset(
              'assets/branding/makon3d_mark.svg',
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
