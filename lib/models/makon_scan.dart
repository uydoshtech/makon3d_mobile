class MakonScan {
  const MakonScan({
    required this.id,
    this.usdzUrl,
    this.glbUrl,
    this.texturedGlbUrl,
    this.photogrammetryStatus,
    this.floorLongM,
    this.floorShortM,
    this.heightM,
    this.floorAreaM2,
    this.wallPerimeterM,
    this.doorwayWidthM,
    this.doorwayAreaM2,
    this.windowAreaM2,
    this.worldPlusXBearingDeg,
    this.rotationGifUrl,
    this.posterImageUrl,
    this.viewerUrl,
    this.mediaGenerationStatus,
    this.createdAt,
  });

  final int id;
  final String? usdzUrl;
  final String? glbUrl;
  final String? texturedGlbUrl;
  final String? photogrammetryStatus;
  final double? floorLongM;
  final double? floorShortM;
  final double? heightM;
  final double? floorAreaM2;

  /// Wall-run metrics measured by the backend from the converted GLB.
  final double? wallPerimeterM;
  final double? doorwayWidthM;
  final double? doorwayAreaM2;
  final double? windowAreaM2;
  final double? worldPlusXBearingDeg;
  final String? rotationGifUrl;
  final String? posterImageUrl;
  final String? viewerUrl;
  final String? mediaGenerationStatus;
  final DateTime? createdAt;

  factory MakonScan.fromJson(Map<String, dynamic> json) {
    return MakonScan(
      id: (json["id"] as num?)?.toInt() ?? 0,
      usdzUrl: json["usdzUrl"] as String?,
      glbUrl: json["glbUrl"] as String?,
      texturedGlbUrl: json["texturedGlbUrl"] as String?,
      photogrammetryStatus: json["photogrammetryStatus"] as String?,
      floorLongM: (json["floorLongM"] as num?)?.toDouble(),
      floorShortM: (json["floorShortM"] as num?)?.toDouble(),
      heightM: (json["heightM"] as num?)?.toDouble(),
      floorAreaM2: (json["floorAreaM2"] as num?)?.toDouble(),
      wallPerimeterM: (json["wallPerimeterM"] as num?)?.toDouble(),
      doorwayWidthM: (json["doorwayWidthM"] as num?)?.toDouble(),
      doorwayAreaM2: (json["doorwayAreaM2"] as num?)?.toDouble(),
      windowAreaM2: (json["windowAreaM2"] as num?)?.toDouble(),
      worldPlusXBearingDeg: (json["worldPlusXBearingDeg"] as num?)?.toDouble(),
      rotationGifUrl: json["rotationGifUrl"] as String?,
      posterImageUrl: json["posterImageUrl"] as String?,
      viewerUrl: json["viewerUrl"] as String?,
      mediaGenerationStatus: json["mediaGenerationStatus"] as String?,
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"].toString())
          : null,
    );
  }
}
