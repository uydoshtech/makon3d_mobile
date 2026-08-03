import 'package:flutter_test/flutter_test.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';

void main() {
  test('S3 USDZ migration clears a legacy EC2 GLB URL', () {
    const legacy = HousingScan(
      id: 'scan',
      remoteScanId: 27,
      usdzUrl: '/images/makon3d/27/room_scan.usdz',
      glbUrl: '/images/makon3d/27/room_scan.glb',
    );

    final migrated = legacy.withRemoteMedia(
      remoteScanId: 27,
      usdzUrl: 'https://cdn.example/makon3d/scans/27/model.usdz',
    );

    expect(migrated.usdzUrl, contains('cdn.example'));
    expect(migrated.glbUrl, isNull);
  });

  test('remote GLB URL is retained when the backend still supplies one', () {
    const scan = HousingScan(id: 'scan');

    final updated = scan.withRemoteMedia(
      remoteScanId: 29,
      usdzUrl: 'https://cdn.example/room.usdz',
      glbUrl: 'https://cdn.example/room.glb',
    );

    expect(updated.glbUrl, 'https://cdn.example/room.glb');
  });
}
