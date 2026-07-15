/// Footprint of a RoomPlan scan, computed on-device from the USDZ bounds
/// (see RoomScanBoundsService / RoomScanBoundsPlugin.swift).
class RoomScanMetrics {
  const RoomScanMetrics({
    required this.floorLongM,
    required this.floorShortM,
    required this.heightM,
    required this.floorAreaM2,
    this.worldPlusXBearingDeg,
  });

  final double floorLongM;
  final double floorShortM;
  final double heightM;
  final double floorAreaM2;

  /// Geographic bearing of AR world +X at scan time (degrees clockwise from
  /// true north), when the compass sidecar was available.
  final double? worldPlusXBearingDeg;

  Map<String, dynamic> toJson() => <String, dynamic>{
        "floor_long_m": floorLongM,
        "floor_short_m": floorShortM,
        "height_m": heightM,
        "floor_area_m2": floorAreaM2,
        if (worldPlusXBearingDeg != null)
          "world_plus_x_bearing_deg": worldPlusXBearingDeg,
      };
}
