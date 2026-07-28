/// A single whole-property (or single-room) scan artifact attached to a project.
class HousingScan {
  const HousingScan({
    required this.id,
    this.localUsdzPath,
    this.remoteScanId,
    this.usdzUrl,
    this.glbUrl,
    this.floorLongM,
    this.floorShortM,
    this.heightM,
    this.floorAreaM2,
    this.wallPerimeterM,
    this.doorwayWidthM,
    this.doorwayAreaM2,
    this.windowAreaM2,
    this.worldPlusXBearingDeg,
    this.capturedAt,
  });

  final String id;
  final String? localUsdzPath;
  final int? remoteScanId;
  final String? usdzUrl;
  final String? glbUrl;
  final double? floorLongM;
  final double? floorShortM;
  final double? heightM;
  final double? floorAreaM2;

  /// Wall-run metrics the backend measures from the converted GLB
  /// (true wall perimeter, door/opening widths, opening face areas) —
  /// null for scans captured before the backend exposed them.
  final double? wallPerimeterM;
  final double? doorwayWidthM;
  final double? doorwayAreaM2;
  final double? windowAreaM2;
  final double? worldPlusXBearingDeg;
  final DateTime? capturedAt;

  bool get hasModel =>
      (localUsdzPath != null && localUsdzPath!.isNotEmpty) ||
      (usdzUrl != null && usdzUrl!.isNotEmpty) ||
      (glbUrl != null && glbUrl!.isNotEmpty);

  /// Measurements survive even when the USDZ was deleted from the server.
  bool get hasMeasurements =>
      floorLongM != null ||
      floorShortM != null ||
      heightM != null ||
      floorAreaM2 != null;

  /// Drop file/URL pointers after the remote scan row (or local USDZ) is gone.
  /// Keeps dimensions so the room still shows as scanned.
  HousingScan withoutModelMedia() {
    return HousingScan(
      id: id,
      remoteScanId: null,
      floorLongM: floorLongM,
      floorShortM: floorShortM,
      heightM: heightM,
      floorAreaM2: floorAreaM2,
      wallPerimeterM: wallPerimeterM,
      doorwayWidthM: doorwayWidthM,
      doorwayAreaM2: doorwayAreaM2,
      windowAreaM2: windowAreaM2,
      worldPlusXBearingDeg: worldPlusXBearingDeg,
      capturedAt: capturedAt,
    );
  }

  HousingScan withRemoteMedia({
    required int remoteScanId,
    String? usdzUrl,
    String? glbUrl,
  }) {
    return copyWith(
      remoteScanId: remoteScanId,
      usdzUrl: usdzUrl,
      glbUrl: glbUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'localUsdzPath': localUsdzPath,
    'remoteScanId': remoteScanId,
    'usdzUrl': usdzUrl,
    'glbUrl': glbUrl,
    'floorLongM': floorLongM,
    'floorShortM': floorShortM,
    'heightM': heightM,
    'floorAreaM2': floorAreaM2,
    'wallPerimeterM': wallPerimeterM,
    'doorwayWidthM': doorwayWidthM,
    'doorwayAreaM2': doorwayAreaM2,
    'windowAreaM2': windowAreaM2,
    'worldPlusXBearingDeg': worldPlusXBearingDeg,
    'capturedAt': capturedAt?.toIso8601String(),
  };

  factory HousingScan.fromJson(Map<String, dynamic> json) {
    return HousingScan(
      id: json['id'] as String? ?? '',
      localUsdzPath: json['localUsdzPath'] as String?,
      remoteScanId: (json['remoteScanId'] as num?)?.toInt(),
      usdzUrl: json['usdzUrl'] as String?,
      glbUrl: json['glbUrl'] as String?,
      floorLongM: (json['floorLongM'] as num?)?.toDouble(),
      floorShortM: (json['floorShortM'] as num?)?.toDouble(),
      heightM: (json['heightM'] as num?)?.toDouble(),
      floorAreaM2: (json['floorAreaM2'] as num?)?.toDouble(),
      wallPerimeterM: (json['wallPerimeterM'] as num?)?.toDouble(),
      doorwayWidthM: (json['doorwayWidthM'] as num?)?.toDouble(),
      doorwayAreaM2: (json['doorwayAreaM2'] as num?)?.toDouble(),
      windowAreaM2: (json['windowAreaM2'] as num?)?.toDouble(),
      worldPlusXBearingDeg: (json['worldPlusXBearingDeg'] as num?)?.toDouble(),
      capturedAt: json['capturedAt'] != null
          ? DateTime.tryParse(json['capturedAt'].toString())
          : null,
    );
  }

  HousingScan copyWith({
    String? localUsdzPath,
    int? remoteScanId,
    String? usdzUrl,
    String? glbUrl,
    double? floorLongM,
    double? floorShortM,
    double? heightM,
    double? floorAreaM2,
    double? wallPerimeterM,
    double? doorwayWidthM,
    double? doorwayAreaM2,
    double? windowAreaM2,
    double? worldPlusXBearingDeg,
    DateTime? capturedAt,
  }) {
    return HousingScan(
      id: id,
      localUsdzPath: localUsdzPath ?? this.localUsdzPath,
      remoteScanId: remoteScanId ?? this.remoteScanId,
      usdzUrl: usdzUrl ?? this.usdzUrl,
      glbUrl: glbUrl ?? this.glbUrl,
      floorLongM: floorLongM ?? this.floorLongM,
      floorShortM: floorShortM ?? this.floorShortM,
      heightM: heightM ?? this.heightM,
      floorAreaM2: floorAreaM2 ?? this.floorAreaM2,
      wallPerimeterM: wallPerimeterM ?? this.wallPerimeterM,
      doorwayWidthM: doorwayWidthM ?? this.doorwayWidthM,
      doorwayAreaM2: doorwayAreaM2 ?? this.doorwayAreaM2,
      windowAreaM2: windowAreaM2 ?? this.windowAreaM2,
      worldPlusXBearingDeg: worldPlusXBearingDeg ?? this.worldPlusXBearingDeg,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}
