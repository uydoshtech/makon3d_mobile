import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/services/floor_tile_layout.dart';

class FloorTileLayoutScreen extends StatelessWidget {
  const FloorTileLayoutScreen({
    required this.roomName,
    required this.roomWidthM,
    required this.roomLengthM,
    required this.tileWidthCm,
    required this.tileLengthCm,
    required this.purchaseTileCount,
    super.key,
  });

  final String roomName;
  final double roomWidthM;
  final double roomLengthM;
  final double tileWidthCm;
  final double tileLengthCm;
  final int purchaseTileCount;

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = FloorTileLayout(
      roomWidthM: roomWidthM,
      roomLengthM: roomLengthM,
      tileWidthCm: tileWidthCm,
      tileLengthCm: tileLengthCm,
    );

    return Scaffold(
      appBar: AppBar(title: Text(L10n.get('materials_tile_layout_title'))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                roomName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                L10n.get('materials_tile_layout_subtitle_template')
                    .replaceAll('{width}', _formatNumber(tileWidthCm))
                    .replaceAll('{length}', _formatNumber(tileLengthCm)),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                L10n.get('materials_tile_layout_plan_heading'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              L10n.get('materials_tile_layout_top_view'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: theme.colorScheme.surfaceContainer,
                          child: _TilePlanViewport(layout: layout),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          children: [
                            _LegendRow(
                              icon: Icons.trending_flat_rounded,
                              color: theme.colorScheme.secondary,
                              label: L10n.get(
                                'materials_tile_layout_direction_legend',
                              ),
                            ),
                            const SizedBox(height: 7),
                            _LegendRow(
                              icon: Icons.border_outer_rounded,
                              color: theme.colorScheme.primary,
                              label: L10n.get(
                                'materials_tile_layout_cut_legend',
                              ),
                            ),
                            const SizedBox(height: 7),
                            _LegendRow(
                              icon: Icons.pinch_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                              label: L10n.get(
                                'materials_tile_layout_zoom_hint',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                L10n.get('materials_tile_layout_count_template')
                    .replaceAll('{rows}', layout.rows.toString())
                    .replaceAll('{columns}', layout.columns.toString())
                    .replaceAll('{positions}', layout.positionCount.toString())
                    .replaceAll('{purchase}', purchaseTileCount.toString()),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                L10n.get('materials_tile_layout_approximate_note'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _TilePlanViewport extends StatelessWidget {
  const _TilePlanViewport({required this.layout});

  final FloorTileLayout layout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: L10n.get(
        'materials_tile_layout_semantics',
      ).replaceAll('{count}', layout.positionCount.toString()),
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 12,
        boundaryMargin: const EdgeInsets.all(96),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = math.max(1.0, constraints.maxWidth - 38);
            const startLabelScale = 1 / 3;
            const startLabelSpace = 14.0;
            final maxHeight = math.max(
              1.0,
              constraints.maxHeight - 38 - startLabelSpace,
            );
            var planWidth = maxWidth;
            var planHeight = planWidth / layout.roomAspectRatio;
            if (planHeight > maxHeight) {
              planHeight = maxHeight;
              planWidth = planHeight * layout.roomAspectRatio;
            }
            return Center(
              child: SizedBox(
                width: planWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      key: const ValueKey('tile-layout-start-label'),
                      decoration: BoxDecoration(
                        color: colors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(
                          20 * startLabelScale,
                        ),
                        border: Border.all(
                          color: colors.tertiary,
                          width: startLabelScale,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7 * startLabelScale,
                          vertical: 3 * startLabelScale,
                        ),
                        child: Text(
                          L10n.get('materials_tile_layout_start'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onTertiaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.fontSize ??
                                        11) *
                                    startLabelScale,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    CustomPaint(
                      key: const ValueKey('tile-layout-plan'),
                      size: Size(planWidth, planHeight),
                      painter: _TilePlanPainter(layout: layout, colors: colors),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TilePlanPainter extends CustomPainter {
  const _TilePlanPainter({required this.layout, required this.colors});

  final FloorTileLayout layout;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final roomRect = Offset.zero & size;
    canvas.drawRect(
      roomRect,
      Paint()
        ..color = colors.surface
        ..style = PaintingStyle.fill,
    );

    final gridPaint = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final cutPaint = Paint()
      ..color = colors.primary
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final rects = <Rect>[];
    for (var row = 0; row < layout.rows; row++) {
      final top = math.min(
        size.height,
        row * layout.tileLengthM / layout.roomLengthM * size.height,
      );
      final bottom = math.min(
        size.height,
        (row + 1) * layout.tileLengthM / layout.roomLengthM * size.height,
      );
      for (var column = 0; column < layout.columns; column++) {
        final left = math.min(
          size.width,
          column * layout.tileWidthM / layout.roomWidthM * size.width,
        );
        final right = math.min(
          size.width,
          (column + 1) * layout.tileWidthM / layout.roomWidthM * size.width,
        );
        final rect = Rect.fromLTRB(left, top, right, bottom);
        rects.add(rect);
        if ((row + column).isOdd) {
          canvas.drawRect(
            rect.deflate(0.35),
            Paint()
              ..color = colors.surfaceContainerHighest.withValues(alpha: 0.55)
              ..style = PaintingStyle.fill,
          );
        }
        canvas.drawRect(rect, gridPaint);
        if (layout.isCutPosition(row, column)) {
          final inset = math.min(1.1, math.min(rect.width, rect.height) / 4);
          canvas.drawRect(rect.deflate(inset), cutPaint);
        }
      }
    }

    _paintDirectionPath(canvas, rects);
    _paintNumbers(canvas, rects, size);

    canvas.drawRect(
      roomRect,
      Paint()
        ..color = colors.onSurface
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintDirectionPath(Canvas canvas, List<Rect> rects) {
    if (rects.isEmpty) return;
    final firstTile = rects.first;
    final routeWidth = math.max(1.6, math.min(3.4, firstTile.height * 0.14));
    final routeColor = colors.secondary;
    final pathOutlinePaint = Paint()
      ..color = colors.onSurface.withValues(alpha: 0.18)
      ..strokeWidth = routeWidth + 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final pathPaint = Paint()
      ..color = routeColor
      ..strokeWidth = routeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var row = 0; row < layout.rows; row++) {
      final first = rects[row * layout.columns];
      final last = rects[row * layout.columns + layout.columns - 1];
      final start = row.isEven ? _directionPoint(first) : _directionPoint(last);
      final end = row.isEven ? _directionPoint(last) : _directionPoint(first);
      if (row == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.lineTo(end.dx, end.dy);
    }
    canvas.drawPath(path, pathOutlinePaint);
    canvas.drawPath(path, pathPaint);

    for (var row = 0; row < layout.rows; row++) {
      final first = rects[row * layout.columns];
      final last = rects[row * layout.columns + layout.columns - 1];
      final from = row.isEven ? _directionPoint(first) : _directionPoint(last);
      final to = row.isEven ? _directionPoint(last) : _directionPoint(first);
      final direction = (to - from).direction;
      final tip = Offset.lerp(from, to, 0.72)!;
      final arrowSize = math.max(
        3.2,
        math.min(8.0, math.min(first.width, first.height) * 0.42),
      );
      final unit = Offset(math.cos(direction), math.sin(direction));
      final normal = Offset(-unit.dy, unit.dx);
      final baseCenter = tip - unit * arrowSize;
      final arrow = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          baseCenter.dx + normal.dx * arrowSize * 0.62,
          baseCenter.dy + normal.dy * arrowSize * 0.62,
        )
        ..lineTo(
          baseCenter.dx - normal.dx * arrowSize * 0.62,
          baseCenter.dy - normal.dy * arrowSize * 0.62,
        )
        ..close();
      canvas.drawPath(
        arrow,
        Paint()
          ..color = colors.onSurface.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawPath(
        arrow,
        Paint()
          ..color = routeColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  Offset _directionPoint(Rect tile) =>
      Offset(tile.center.dx, tile.top + tile.height * 0.24);

  void _paintNumbers(Canvas canvas, List<Rect> rects, Size size) {
    final roomBorderInset = math.min(
      2.2,
      math.min(size.width, size.height) / 4,
    );
    final safeRoomRect = (Offset.zero & size).deflate(roomBorderInset);
    final maxDigitCount = layout.positionCount.toString().length;
    final fontSizeByDigitCount = <int, double>{
      for (var digits = 1; digits <= maxDigitCount; digits++)
        digits: _numberFontSize(rects, digits),
    };
    for (var row = 0; row < layout.rows; row++) {
      for (var column = 0; column < layout.columns; column++) {
        final rect = rects[row * layout.columns + column];
        final number = layout.tileNumberAt(row, column).toString();
        final fontSize = fontSizeByDigitCount[number.length]!;
        final textPainter = _numberPainter(number, fontSize);

        final horizontalPadding = math.min(fontSize * 0.22, 1.2);
        final verticalPadding = math.min(fontSize * 0.16, 0.8);
        final labelWidth = math.min(
          safeRoomRect.width,
          textPainter.width + horizontalPadding * 2,
        );
        final labelHeight = math.min(
          safeRoomRect.height,
          textPainter.height + verticalPadding * 2,
        );
        final minCenterX = safeRoomRect.left + labelWidth / 2;
        final maxCenterX = safeRoomRect.right - labelWidth / 2;
        final minCenterY = safeRoomRect.top + labelHeight / 2;
        final maxCenterY = safeRoomRect.bottom - labelHeight / 2;
        final labelCenter = Offset(
          maxCenterX >= minCenterX
              ? rect.center.dx.clamp(minCenterX, maxCenterX).toDouble()
              : safeRoomRect.center.dx,
          maxCenterY >= minCenterY
              ? rect.center.dy.clamp(minCenterY, maxCenterY).toDouble()
              : safeRoomRect.center.dy,
        );
        final labelRect = Rect.fromCenter(
          center: labelCenter,
          width: labelWidth,
          height: labelHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(labelRect, Radius.circular(labelHeight / 2)),
          Paint()
            ..color = colors.surface.withValues(alpha: 0.92)
            ..style = PaintingStyle.fill,
        );
        textPainter.paint(
          canvas,
          labelCenter - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  double _numberFontSize(List<Rect> rects, int digitCount) {
    if (rects.isEmpty) return 1;
    var nominalWidth = 0.0;
    var nominalHeight = 0.0;
    for (final rect in rects) {
      nominalWidth = math.max(nominalWidth, rect.width);
      nominalHeight = math.max(nominalHeight, rect.height);
    }

    final availableWidth = math.max(0.5, nominalWidth - 1.2);
    final availableHeight = math.max(0.5, nominalHeight - 1.2);
    var fontSize = math.max(0.5, math.min(10.0, nominalHeight * 0.34));
    final widestReference = List.filled(digitCount, '8').join();
    final referencePainter = _numberPainter(widestReference, fontSize);
    if (referencePainter.width > availableWidth ||
        referencePainter.height > availableHeight) {
      final fitScale = math.min(
        availableWidth / referencePainter.width,
        availableHeight / referencePainter.height,
      );
      fontSize = math.max(0.35, fontSize * fitScale);
    }
    return fontSize;
  }

  TextPainter _numberPainter(String number, double fontSize) {
    return TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _TilePlanPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.colors != colors;
}
