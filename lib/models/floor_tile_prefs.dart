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

  /// Lenient parse for optional persisted prefs; null when absent/invalid.
  static FloorTilePrefs? tryFromJson(Object? json) {
    if (json is Map<String, dynamic>) return FloorTilePrefs.fromJson(json);
    if (json is Map) {
      return FloorTilePrefs.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

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
