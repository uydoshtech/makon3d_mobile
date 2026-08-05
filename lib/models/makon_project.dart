import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/models/floor_tile_prefs.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/models/wallpaper_prefs.dart';

/// Makon3D project. [scanMode] is immutable after creation (v1).
class MakonProject {
  const MakonProject({
    required this.id,
    required this.name,
    required this.scanMode,
    required this.createdAt,
    this.address,
    this.notes,
    this.entireHousingScan,
    this.rooms = const [],
    this.mergedStructureLocalPath,
    this.entireHousingFloorTilePrefs,
    this.entireHousingWallpaperPrefs,
    this.contractorListing,
  });

  final String id;
  final String name;
  final ScanMode scanMode;
  final DateTime createdAt;
  final String? address;
  final String? notes;
  final HousingScan? entireHousingScan;
  final List<ProjectRoom> rooms;

  /// Optional path to a combined USDZ generated from room scans (future).
  final String? mergedStructureLocalPath;

  /// Floor-tile settings when [scanMode] is entire housing (one space).
  final FloorTilePrefs? entireHousingFloorTilePrefs;

  /// Wallpaper settings when [scanMode] is entire housing (one space).
  final WallpaperPrefs? entireHousingWallpaperPrefs;

  /// Public brief currently searchable by contractors, when present.
  final ContractorListing? contractorListing;

  bool get hasEntireHousingModel => entireHousingScan?.hasModel == true;

  int get scannedRoomCount => rooms.where((r) => r.isScanned).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'scanMode': scanMode.wireValue,
    'createdAt': createdAt.toIso8601String(),
    'address': address,
    'notes': notes,
    'entireHousingScan': entireHousingScan?.toJson(),
    'rooms': rooms.map((r) => r.toJson()).toList(),
    'mergedStructureLocalPath': mergedStructureLocalPath,
    'entireHousingFloorTilePrefs': entireHousingFloorTilePrefs?.toJson(),
    'entireHousingWallpaperPrefs': entireHousingWallpaperPrefs?.toJson(),
    'contractorListing': contractorListing?.toJson(),
  };

  factory MakonProject.fromJson(Map<String, dynamic> json) {
    final roomsJson = json['rooms'];
    final rooms = <ProjectRoom>[];
    if (roomsJson is List) {
      for (final item in roomsJson) {
        if (item is Map<String, dynamic>) {
          rooms.add(ProjectRoom.fromJson(item));
        } else if (item is Map) {
          rooms.add(ProjectRoom.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Migration: missing scanMode — infer from content.
    final parsedMode = ScanMode.tryParse(json['scanMode'] as String?);
    Map<String, dynamic>? entireJson;
    final rawEntire = json['entireHousingScan'];
    if (rawEntire is Map<String, dynamic>) {
      entireJson = rawEntire;
    } else if (rawEntire is Map) {
      entireJson = Map<String, dynamic>.from(rawEntire);
    }
    final entire = entireJson != null ? HousingScan.fromJson(entireJson) : null;
    final scanMode =
        parsedMode ?? migrateScanMode(entireHousingScan: entire, rooms: rooms);

    return MakonProject(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Project',
      scanMode: scanMode,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      entireHousingScan: entire,
      rooms: rooms,
      mergedStructureLocalPath: json['mergedStructureLocalPath'] as String?,
      entireHousingFloorTilePrefs:
          json['entireHousingFloorTilePrefs'] is Map<String, dynamic>
          ? FloorTilePrefs.fromJson(
              json['entireHousingFloorTilePrefs'] as Map<String, dynamic>,
            )
          : json['entireHousingFloorTilePrefs'] is Map
          ? FloorTilePrefs.fromJson(
              Map<String, dynamic>.from(
                json['entireHousingFloorTilePrefs'] as Map,
              ),
            )
          : null,
      entireHousingWallpaperPrefs: WallpaperPrefs.tryFromJson(
        json['entireHousingWallpaperPrefs'],
      ),
      contractorListing: ContractorListing.tryFromJson(
        json['contractorListing'],
      ),
    );
  }

  /// Safe default for legacy projects that lack [scanMode].
  ///
  /// - Multiple independent room scans → [ScanMode.roomByRoom]
  /// - Otherwise → [ScanMode.entireHousing]
  static ScanMode migrateScanMode({
    HousingScan? entireHousingScan,
    List<ProjectRoom> rooms = const [],
  }) {
    final independentRoomScans = rooms.where((r) => r.isScanned).length;
    if (independentRoomScans > 1) {
      return ScanMode.roomByRoom;
    }
    if (independentRoomScans == 1 && entireHousingScan == null) {
      return ScanMode.roomByRoom;
    }
    return ScanMode.entireHousing;
  }

  MakonProject copyWith({
    String? name,
    String? address,
    String? notes,
    HousingScan? entireHousingScan,
    List<ProjectRoom>? rooms,
    String? mergedStructureLocalPath,
    FloorTilePrefs? entireHousingFloorTilePrefs,
    WallpaperPrefs? entireHousingWallpaperPrefs,
    ContractorListing? contractorListing,
    bool clearEntireHousingScan = false,
    bool clearAddress = false,
    bool clearNotes = false,
    bool clearContractorListing = false,
  }) {
    return MakonProject(
      id: id,
      name: name ?? this.name,
      scanMode: scanMode,
      createdAt: createdAt,
      address: clearAddress ? null : (address ?? this.address),
      notes: clearNotes ? null : (notes ?? this.notes),
      entireHousingScan: clearEntireHousingScan
          ? null
          : (entireHousingScan ?? this.entireHousingScan),
      rooms: rooms ?? this.rooms,
      mergedStructureLocalPath:
          mergedStructureLocalPath ?? this.mergedStructureLocalPath,
      entireHousingFloorTilePrefs:
          entireHousingFloorTilePrefs ?? this.entireHousingFloorTilePrefs,
      entireHousingWallpaperPrefs:
          entireHousingWallpaperPrefs ?? this.entireHousingWallpaperPrefs,
      contractorListing: clearContractorListing
          ? null
          : (contractorListing ?? this.contractorListing),
    );
  }
}
