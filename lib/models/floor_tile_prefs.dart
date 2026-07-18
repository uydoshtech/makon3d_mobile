/// Per-room (or entire-housing) floor tile estimate settings.
class FloorTilePrefs {
  const FloorTilePrefs({
    this.widthCm = 40,
    this.heightCm = 40,
    this.wastePercent = 10,
  });

  static const defaults = FloorTilePrefs();

  final double widthCm;
  final double heightCm;
  final double wastePercent;

  bool get isSquare => (widthCm - heightCm).abs() < 0.001;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'widthCm': widthCm,
        'heightCm': heightCm,
        'wastePercent': wastePercent,
      };

  factory FloorTilePrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return FloorTilePrefs(
      widthCm: (json['widthCm'] as num?)?.toDouble() ?? defaults.widthCm,
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? defaults.heightCm,
      wastePercent:
          (json['wastePercent'] as num?)?.toDouble() ?? defaults.wastePercent,
    );
  }

  FloorTilePrefs copyWith({
    double? widthCm,
    double? heightCm,
    double? wastePercent,
  }) {
    return FloorTilePrefs(
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      wastePercent: wastePercent ?? this.wastePercent,
    );
  }
}
