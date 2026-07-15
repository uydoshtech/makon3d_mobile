import "package:flutter/services.dart";

import "package:makon3d_mobile/base/ios_device.dart";
import "package:makon3d_mobile/l10n/l10n.dart";

/// Presents the native SceneKit USDZ viewer (RoomUsdzViewerViewController)
/// for a local scan file. Channel and string keys are shared with UyDosh so
/// the native viewer stack is used unmodified.
class RoomUsdzViewerService {
  RoomUsdzViewerService._();

  static const MethodChannel _channel = MethodChannel("uydosh/room_usdz_viewer");
  static bool _presentInFlight = false;

  /// Matches UyDosh's `AppColors.floorObject3dTint` (0xFF795548).
  static const String _floorObjectTintHex = "795548";

  /// Returns true if the native viewer was presented.
  static Future<bool> presentLocalFile(
    String path, {
    required String languageCode,
    double? worldPlusXBearingDeg,
  }) async {
    if (!isIOSDevice) return false;
    if (_presentInFlight) return false;
    _presentInFlight = true;
    try {
      String l(String key) => L10n.getForLanguage(key, languageCode);
      final strings = <String, String>{
        "title": l("room_3d_viewer_title"),
        "dimensionsCaption": l("room_3d_dimensions_caption"),
        "dimensionsLine1Template": l("room_3d_dimensions_line1_template"),
        "dimensionsHeightTemplate": l("room_3d_dimensions_height_template"),
        "dimensionsLine2Template": l("room_3d_dimensions_line2_template"),
        "loadErrorTitle": l("room_3d_load_error_title"),
        "alertOk": l("ok"),
        "floorOnlyButton": l("room_3d_floor_only_button"),
        "fullRoomButton": l("room_3d_full_room_button"),
        "floorOnlyUnavailable": l("room_3d_floor_only_unavailable"),
        "zoomIn": l("room_3d_zoom_in"),
        "zoomOut": l("room_3d_zoom_out"),
        "viewModeLabel": l("room_3d_view_mode_label"),
        "viewModeHint": l("room_3d_view_mode_hint"),
        "materialsStyleLabel": l("room_3d_materials_style_label"),
        "materialsStyleHint": l("room_3d_materials_style_hint"),
        "materialsStylizedValue": l("room_3d_materials_style_value_stylized"),
        "materialsRealValue": l("room_3d_materials_style_value_real"),
        "brandMarkA11yLabel": l("app_name"),
        "onFloorTintRgb": _floorObjectTintHex,
        "tab3DView": l("room_3d_tab_view_3d"),
        "tabFloorPlan": l("room_3d_tab_floor_plan"),
        "floorPlanReset": l("room_3d_floor_plan_reset"),
        "floorPlanDimensionsOverall": l("room_3d_floor_plan_dimensions_overall"),
        "floorPlanDimensionsWalls": l("room_3d_floor_plan_dimensions_walls"),
        "floorPlanDimensionsHide": l("room_3d_floor_plan_dimensions_hide"),
        "floorPlanShowObjects": l("room_3d_floor_plan_show_objects"),
        "floorPlanHideObjects": l("room_3d_floor_plan_hide_objects"),
        "floorPlanShowGrid": l("room_3d_floor_plan_show_grid"),
        "floorPlanHideGrid": l("room_3d_floor_plan_hide_grid"),
        "floorPlanAutoAlignOn": l("room_3d_floor_plan_auto_align_on"),
        "floorPlanAutoAlignOff": l("room_3d_floor_plan_auto_align_off"),
        "floorPlanAdjustNorth": l("room_3d_floor_plan_adjust_north"),
        "floorPlanAdjustNorthTitle": l("room_3d_floor_plan_adjust_north_title"),
        "floorPlanAdjustNorthMessage":
            l("room_3d_floor_plan_adjust_north_message"),
        "floorPlanAdjustNorthReset": l("room_3d_floor_plan_adjust_north_reset"),
        "floorPlanAdjustNorthUpdated":
            l("room_3d_floor_plan_adjust_north_updated"),
        "floorPlanAdjustNorthDegreesFormat":
            l("room_3d_floor_plan_adjust_north_degrees_format"),
        "floorPlanEditDimensionTitle":
            l("room_3d_floor_plan_edit_dimension_title"),
        "floorPlanEditDimensionCurrent":
            l("room_3d_floor_plan_edit_dimension_current"),
        "floorPlanEditDimensionNewValue":
            l("room_3d_floor_plan_edit_dimension_new_value"),
        "floorPlanEditDimensionCancel":
            l("room_3d_floor_plan_edit_dimension_cancel"),
        "floorPlanEditDimensionApply":
            l("room_3d_floor_plan_edit_dimension_apply"),
        "floorPlanEditDimensionUpdated":
            l("room_3d_floor_plan_edit_dimension_updated"),
        "floorPlanEditDimensionLargeChangeTitle":
            l("room_3d_floor_plan_edit_dimension_large_change_title"),
        "floorPlanEditDimensionLargeChangeMessage":
            l("room_3d_floor_plan_edit_dimension_large_change_message"),
        "floorPlanEditDimensionInvalidTitle":
            l("room_3d_floor_plan_edit_dimension_invalid_title"),
        "floorPlanEditDimensionInvalidMessage":
            l("room_3d_floor_plan_edit_dimension_invalid_message"),
        "floorPlanEditDimensionConfirmLargeChange":
            l("room_3d_floor_plan_edit_dimension_confirm_large_change"),
        "floorPlanUnitMeters": l("room_3d_floor_plan_unit_meters"),
        "floorPlanObjectBed": l("room_3d_floor_plan_object_bed"),
        "floorPlanObjectSofa": l("room_3d_floor_plan_object_sofa"),
        "floorPlanObjectTable": l("room_3d_floor_plan_object_table"),
        "floorPlanObjectChair": l("room_3d_floor_plan_object_chair"),
        "floorPlanObjectStorage": l("room_3d_floor_plan_object_storage"),
        "floorPlanObjectAppliance": l("room_3d_floor_plan_object_appliance"),
        "floorPlanObjectCabinet": l("room_3d_floor_plan_object_cabinet"),
        "floorPlanObjectTelevision": l("room_3d_floor_plan_object_television"),
        "floorPlanObjectFixture": l("room_3d_floor_plan_object_fixture"),
        "floorPlanObjectUnknown": l("room_3d_floor_plan_object_unknown"),
        "sunToggleLabel": l("room_3d_sun_toggle_label"),
        "sunToggleHint": l("room_3d_sun_toggle_hint"),
        "sunAzimuthLabel": l("room_3d_sun_azimuth_label"),
        "sunElevationLabel": l("room_3d_sun_elevation_label"),
        "sunIntensityLabel": l("room_3d_sun_intensity_label"),
        "sunPresetMorning": l("room_3d_sun_preset_morning"),
        "sunPresetNoon": l("room_3d_sun_preset_noon"),
        "sunPresetEvening": l("room_3d_sun_preset_evening"),
        "sunAzimuthFormat": l("room_3d_sun_azimuth_format"),
        "sunElevationFormat": l("room_3d_sun_elevation_format"),
      };
      final ok = await _channel.invokeMethod<bool>(
        "presentLocalFile",
        <String, dynamic>{
          "path": path,
          "strings": strings,
          "listingId": 0,
          "publishMetricsIfMissing": false,
          "isListingOwner": false,
          "worldPlusXBearingDeg": ?worldPlusXBearingDeg,
        },
      );
      return ok ?? false;
    } finally {
      _presentInFlight = false;
    }
  }
}
