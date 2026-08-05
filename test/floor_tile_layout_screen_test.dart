import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makon3d_mobile/screens/floor_tile_layout_screen.dart';

void main() {
  testWidgets('tile layout fits a phone viewport and exposes zoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const FloorTileLayoutScreen(
          roomName: 'Baha',
          // Leaves a very narrow final cut column, which must still render.
          roomWidthM: 8.43,
          roomLengthM: 10.44,
          tileWidthCm: 40,
          tileLengthCm: 50,
          purchaseTileCount: 461,
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.textContaining('461'), findsOneWidget);
    final startRect = tester.getRect(
      find.byKey(const ValueKey('tile-layout-start-label')),
    );
    final planRect = tester.getRect(
      find.byKey(const ValueKey('tile-layout-plan')),
    );
    expect(startRect.bottom, lessThanOrEqualTo(planRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('slender 10x50 planks render as separate positions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const FloorTileLayoutScreen(
          roomName: 'Baha',
          roomWidthM: 4.9,
          roomLengthM: 18.5,
          tileWidthCm: 10,
          tileLengthCm: 50,
          purchaseTileCount: 1843,
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.textContaining('1813'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
