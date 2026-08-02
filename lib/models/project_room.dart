import 'package:makon3d_mobile/models/floor_tile_prefs.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/room_type.dart';
import 'package:makon3d_mobile/models/wallpaper_prefs.dart';

/// One independently scanned room inside a room-by-room Makon project.
class ProjectRoom {
  const ProjectRoom({
    required this.id,
    required this.roomType,
    required this.createdAt,
    this.name,
    this.scan,
    this.layoutOffsetXM,
    this.layoutOffsetZM,
    this.layoutYawDeg,
    this.floorTilePrefs,
    this.wallpaperPrefs,
  });

  final String id;
  final RoomType roomType;
  final DateTime createdAt;
  final String? name;
  final HousingScan? scan;

  /// Placement in the combined housing layout (meters / degrees).
  /// Null = use native auto-pack along +X when assembling.
  final double? layoutOffsetXM;
  final double? layoutOffsetZM;
  final double? layoutYawDeg;

  /// Last floor-tile estimate settings for this room (local only).
  final FloorTilePrefs? floorTilePrefs;

  /// Last wallpaper estimate settings for this room (local only).
  final WallpaperPrefs? wallpaperPrefs;

  bool get isScanned =>
      scan != null && (scan!.hasModel || scan!.hasMeasurements);

  bool get hasExplicitLayout =>
      layoutOffsetXM != null && layoutOffsetZM != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'roomType': roomType.wireValue,
    'createdAt': createdAt.toIso8601String(),
    'name': name,
    'scan': scan?.toJson(),
    'layoutOffsetXM': layoutOffsetXM,
    'layoutOffsetZM': layoutOffsetZM,
    'layoutYawDeg': layoutYawDeg,
    'floorTilePrefs': floorTilePrefs?.toJson(),
    'wallpaperPrefs': wallpaperPrefs?.toJson(),
  };

  factory ProjectRoom.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? scanJson;
    final rawScan = json['scan'];
    if (rawScan is Map<String, dynamic>) {
      scanJson = rawScan;
    } else if (rawScan is Map) {
      // Dio / jsonb nested maps are often Map<dynamic, dynamic>.
      scanJson = Map<String, dynamic>.from(rawScan);
    }
    return ProjectRoom(
      id: json['id'] as String? ?? '',
      roomType:
          RoomType.tryParse(json['roomType'] as String?) ?? RoomType.other,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      name: json['name'] as String?,
      scan: scanJson != null ? HousingScan.fromJson(scanJson) : null,
      layoutOffsetXM: (json['layoutOffsetXM'] as num?)?.toDouble(),
      layoutOffsetZM: (json['layoutOffsetZM'] as num?)?.toDouble(),
      layoutYawDeg: (json['layoutYawDeg'] as num?)?.toDouble(),
      floorTilePrefs: json['floorTilePrefs'] is Map<String, dynamic>
          ? FloorTilePrefs.fromJson(
              json['floorTilePrefs'] as Map<String, dynamic>,
            )
          : json['floorTilePrefs'] is Map
          ? FloorTilePrefs.fromJson(
              Map<String, dynamic>.from(json['floorTilePrefs'] as Map),
            )
          : null,
      wallpaperPrefs: WallpaperPrefs.tryFromJson(json['wallpaperPrefs']),
    );
  }

  ProjectRoom copyWith({
    RoomType? roomType,
    String? name,
    HousingScan? scan,
    double? layoutOffsetXM,
    double? layoutOffsetZM,
    double? layoutYawDeg,
    FloorTilePrefs? floorTilePrefs,
    WallpaperPrefs? wallpaperPrefs,
    bool clearLayout = false,
  }) {
    return ProjectRoom(
      id: id,
      roomType: roomType ?? this.roomType,
      createdAt: createdAt,
      name: name ?? this.name,
      scan: scan ?? this.scan,
      layoutOffsetXM: clearLayout
          ? null
          : (layoutOffsetXM ?? this.layoutOffsetXM),
      layoutOffsetZM: clearLayout
          ? null
          : (layoutOffsetZM ?? this.layoutOffsetZM),
      layoutYawDeg: clearLayout ? null : (layoutYawDeg ?? this.layoutYawDeg),
      floorTilePrefs: floorTilePrefs ?? this.floorTilePrefs,
      wallpaperPrefs: wallpaperPrefs ?? this.wallpaperPrefs,
    );
  }
}
