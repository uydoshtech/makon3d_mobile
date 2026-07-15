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
      createdAt: json["createdAt"] != null
          ? DateTime.tryParse(json["createdAt"].toString())
          : null,
    );
  }
}
