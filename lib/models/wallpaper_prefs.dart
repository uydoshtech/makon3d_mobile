/// Per-room (or entire-housing) wallpaper roll estimate settings.
class WallpaperPrefs {
  const WallpaperPrefs({
    this.rollWidthM = 0.53,
    this.rollLengthM = 10.05,
    this.repeatCm = 0,
  });

  /// Standard European roll: 0.53 × 10.05 m.
  static const defaults = WallpaperPrefs();

  final double rollWidthM;
  final double rollLengthM;

  /// Pattern repeat (rapport) — each strip is cut this much longer.
  final double repeatCm;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rollWidthM': rollWidthM,
    'rollLengthM': rollLengthM,
    'repeatCm': repeatCm,
  };

  /// Lenient parse for optional persisted prefs; null when absent/invalid.
  static WallpaperPrefs? tryFromJson(Object? json) {
    if (json is Map<String, dynamic>) return WallpaperPrefs.fromJson(json);
    if (json is Map) {
      return WallpaperPrefs.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

  factory WallpaperPrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return WallpaperPrefs(
      rollWidthM:
          (json['rollWidthM'] as num?)?.toDouble() ?? defaults.rollWidthM,
      rollLengthM:
          (json['rollLengthM'] as num?)?.toDouble() ?? defaults.rollLengthM,
      repeatCm: (json['repeatCm'] as num?)?.toDouble() ?? defaults.repeatCm,
    );
  }

  WallpaperPrefs copyWith({
    double? rollWidthM,
    double? rollLengthM,
    double? repeatCm,
  }) {
    return WallpaperPrefs(
      rollWidthM: rollWidthM ?? this.rollWidthM,
      rollLengthM: rollLengthM ?? this.rollLengthM,
      repeatCm: repeatCm ?? this.repeatCm,
    );
  }
}
