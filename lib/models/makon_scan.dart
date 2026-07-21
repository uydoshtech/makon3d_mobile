class MakonScan {
  const MakonScan({
    required this.id,
    this.usdzUrl,
    this.glbUrl,
    this.floorLongM,
    this.floorShortM,
    this.heightM,
    this.floorAreaM2,
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
  final double? floorLongM;
  final double? floorShortM;
  final double? heightM;
  final double? floorAreaM2;
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
      floorLongM: (json["floorLongM"] as num?)?.toDouble(),
      floorShortM: (json["floorShortM"] as num?)?.toDouble(),
      heightM: (json["heightM"] as num?)?.toDouble(),
      floorAreaM2: (json["floorAreaM2"] as num?)?.toDouble(),
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
