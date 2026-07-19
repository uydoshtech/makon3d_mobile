import "dart:io";

import "package:dio/dio.dart";
import "package:path_provider/path_provider.dart";
import "package:room_scan_kit/room_scan_kit.dart";

import "package:makon3d_mobile/base/ios_device.dart";
import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";

/// Host wrapper: download / l10n, then present via [room_scan_kit].
class RoomUsdzViewerService {
  RoomUsdzViewerService._();

  /// Matches UyDosh's `AppColors.floorObject3dTint` (0xFF795548).
  static const String _floorObjectTintHex = "795548";

  /// Downloads USDZ to the per-scan temp cache (for mini preview or fullscreen).
  /// Returns null on non-iOS. [pathOrUrl] may be relative or absolute.
  static Future<File?> downloadUsdToCache(
    String pathOrUrl, {
    required int scanId,
  }) async {
    if (!isIOSDevice) return null;
    final absolute = ScanUploadService.hostedUrl(pathOrUrl);
    final temp = await getTemporaryDirectory();
    final file = File("${temp.path}/makon3d_scan_$scanId.usdz");
    if (file.existsSync() && file.lengthSync() > 0) {
      return file;
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(minutes: 2),
        responseType: ResponseType.bytes,
      ),
    );
    await dio.download(absolute, file.path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError("Downloaded USDZ is missing or empty");
    }
    return file;
  }

  /// Downloads a remote USDZ (relative or absolute URL) then presents it.
  static Future<bool> downloadAndPresent(
    String pathOrUrl, {
    required int scanId,
    required String languageCode,
    double? worldPlusXBearingDeg,
  }) async {
    final file = await downloadUsdToCache(pathOrUrl, scanId: scanId);
    if (file == null) return false;
    return presentLocalFile(
      file.path,
      languageCode: languageCode,
      worldPlusXBearingDeg: worldPlusXBearingDeg,
    );
  }

  /// Opens fullscreen viewer, matching mini-preview resolution order:
  /// existing local file → download [usdzUrl] → fail.
  ///
  /// Important: a stale non-empty [localUsdzPath] must not block the URL
  /// fallback (iOS temp/Documents paths often vanish after relaunch).
  static Future<bool> openUsdz({
    String? localUsdzPath,
    String? usdzUrl,
    required int scanId,
    required String languageCode,
    double? worldPlusXBearingDeg,
  }) async {
    if (!isIOSDevice) return false;

    final local = localUsdzPath?.trim();
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (file.existsSync() && file.lengthSync() > 0) {
        return presentLocalFile(
          file.path,
          languageCode: languageCode,
          worldPlusXBearingDeg: worldPlusXBearingDeg,
        );
      }
    }

    final url = usdzUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return downloadAndPresent(
        url,
        scanId: scanId,
        languageCode: languageCode,
        worldPlusXBearingDeg: worldPlusXBearingDeg,
      );
    }

    return false;
  }

  /// Returns true if the native viewer was presented.
  static Future<bool> presentLocalFile(
    String path, {
    required String languageCode,
    double? worldPlusXBearingDeg,
  }) async {
    if (!isIOSDevice) return false;
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError("USDZ not found at $path");
    }
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
      "floorPlanAdjustNorthMessage": l("room_3d_floor_plan_adjust_north_message"),
      "floorPlanAdjustNorthReset": l("room_3d_floor_plan_adjust_north_reset"),
      "floorPlanAdjustNorthUpdated": l("room_3d_floor_plan_adjust_north_updated"),
      "floorPlanAdjustNorthDegreesFormat":
          l("room_3d_floor_plan_adjust_north_degrees_format"),
      "floorPlanRotateFurnitureTitle":
          l("room_3d_floor_plan_rotate_furniture_title"),
      "floorPlanRotateFurnitureMessage":
          l("room_3d_floor_plan_rotate_furniture_message"),
      "floorPlanRotateFurnitureUpdated":
          l("room_3d_floor_plan_rotate_furniture_updated"),
      "floorPlanRotateFurnitureDegreesFormat":
          l("room_3d_floor_plan_rotate_furniture_degrees_format"),
      "floorPlanMoveFurnitureUp": l("room_3d_floor_plan_move_furniture_up"),
      "floorPlanMoveFurnitureDown": l("room_3d_floor_plan_move_furniture_down"),
      "floorPlanMoveFurnitureLeft": l("room_3d_floor_plan_move_furniture_left"),
      "floorPlanMoveFurnitureRight": l("room_3d_floor_plan_move_furniture_right"),
      "floorPlanRaiseFurniture": l("room_3d_floor_plan_raise_furniture"),
      "floorPlanLowerFurniture": l("room_3d_floor_plan_lower_furniture"),
      "floorPlanFurnitureVariantTitle":
          l("room_3d_floor_plan_furniture_variant_title"),
      "floorPlanFurnitureVariantAccessibility":
          l("room_3d_floor_plan_furniture_variant_accessibility"),
      "floorPlanFurnitureRotationTitle":
          l("room_3d_floor_plan_furniture_rotation_title"),
      "floorPlanFurnitureColorTitle":
          l("room_3d_floor_plan_furniture_color_title"),
      "floorPlanFurnitureColorPartTitle":
          l("room_3d_floor_plan_furniture_color_part_title"),
      "floorPlanFurnitureColorRoleFrame":
          l("room_3d_floor_plan_furniture_color_role_frame"),
      "floorPlanFurnitureColorRoleFabric":
          l("room_3d_floor_plan_furniture_color_role_fabric"),
      "floorPlanFurnitureColorRoleLinen":
          l("room_3d_floor_plan_furniture_color_role_linen"),
      "floorPlanFurnitureColorDefault":
          l("room_3d_floor_plan_furniture_color_default"),
      "floorPlanFurnitureColorAccessibility":
          l("room_3d_floor_plan_furniture_color_accessibility"),
      "floorPlanDeleteFurniture": l("room_3d_floor_plan_delete_furniture"),
      "floorPlanDeleteFurnitureConfirmTitle":
          l("room_3d_floor_plan_delete_furniture_confirm_title"),
      "floorPlanDeleteFurnitureConfirmMessage":
          l("room_3d_floor_plan_delete_furniture_confirm_message"),
      "floorPlanDeleteFurnitureUpdated":
          l("room_3d_floor_plan_delete_furniture_updated"),
      "floorPlanEditDimensionTitle": l("room_3d_floor_plan_edit_dimension_title"),
      "floorPlanEditDimensionCurrent":
          l("room_3d_floor_plan_edit_dimension_current"),
      "floorPlanEditDimensionNewValue":
          l("room_3d_floor_plan_edit_dimension_new_value"),
      "floorPlanEditDimensionCancel":
          l("room_3d_floor_plan_edit_dimension_cancel"),
      "floorPlanEditDimensionApply": l("room_3d_floor_plan_edit_dimension_apply"),
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
    return RoomUsdzViewer.presentLocalFile(
      path: path,
      strings: strings,
      worldPlusXBearingDeg: worldPlusXBearingDeg,
    );
  }
}
