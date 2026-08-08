import "dart:async";
import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:path_provider/path_provider.dart";
import "package:room_scan_kit/room_scan_kit.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:makon3d_mobile/base/ios_device.dart";
import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/scan_share_service.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";

/// Host wrapper: download / l10n, then present via [room_scan_kit].
///
/// Makon users always own their scans, so the viewer opens in owner-edit mode
/// (`isListingOwner: true` + positive [scanId] as kit `listingId`) so chrome
/// such as Add furniture is visible. Furniture edits persist locally and, when
/// [shareScanId] / a remote scan id is known and the user is signed in, sync
/// to `PATCH /makon3d/scans/:id/furniture-edits` for cross-device restore.
///
/// When [shareScanId] is set (remote API id), the native Share button is shown
/// and shares the server rotation GIF + viewer link.
class RoomUsdzViewerService {
  RoomUsdzViewerService._();

  /// Makon charcoal floor tint matching the black brand mark.
  static const String _floorObjectTintHex = "262626";

  static const String _furnitureEditsPrefsPrefix = "makon_furniture_edits_";

  static bool _furnitureSinkWired = false;
  static bool _shareSinkWired = false;
  static String _shareLanguageCode = "en";
  static final Map<int, int> _shareScanIdByListingId = <int, int>{};

  /// Maps viewer `listingId` → remote API scan id for furniture-edit sync.
  static final Map<int, int> _remoteScanIdByListingId = <int, int>{};

  /// Kit requires `listingId > 0`; [HousingScan.id.hashCode] can be ≤ 0.
  static int viewerListingId(int scanId) {
    final id = scanId.abs();
    return id == 0 ? 1 : id;
  }

  static String _furnitureEditsKey(int listingId) =>
      "$_furnitureEditsPrefsPrefix$listingId";

  static Future<Map<String, dynamic>?> _loadFurnitureEdits(
    int listingId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_furnitureEditsKey(listingId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint("Furniture edits load failed ($listingId): $e");
    }
    return null;
  }

  /// Resolve edits for preview / fullscreen: prefer the signed-in account's
  /// remote document, fall back to on-device prefs, and upload local-only edits
  /// once so older installs migrate into the cloud.
  static Future<Map<String, dynamic>?> loadFurnitureEditsForScan(
    int scanId, {
    int? remoteScanId,
  }) async {
    final listingId = viewerListingId(scanId);
    final syncId = remoteScanId != null && remoteScanId > 0
        ? remoteScanId
        : (scanId > 0 ? scanId : null);
    if (syncId != null) {
      _remoteScanIdByListingId[listingId] = syncId;
    }

    Map<String, dynamic>? remote;
    if (syncId != null) {
      try {
        remote = (await ScanUploadService.getScan(syncId)).furnitureEdits;
      } catch (e) {
        debugPrint("Furniture edits remote fetch failed ($syncId): $e");
      }
    }

    final local = await _loadFurnitureEdits(listingId);
    if (remote != null) {
      await _saveFurnitureEdits(listingId, remote);
      return remote;
    }
    if (local != null && syncId != null) {
      // Device had edits before cloud sync existed — push once.
      unawaited(_pushFurnitureEdits(syncId, local));
    }
    return local;
  }

  static Future<void> _saveFurnitureEdits(
    int listingId,
    Map<String, dynamic>? furnitureEdits,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _furnitureEditsKey(listingId);
    if (furnitureEdits == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(furnitureEdits));
  }

  static Future<void> _pushFurnitureEdits(
    int remoteScanId,
    Map<String, dynamic>? furnitureEdits,
  ) async {
    try {
      await ScanUploadService.patchFurnitureEdits(remoteScanId, furnitureEdits);
    } catch (e) {
      debugPrint("Furniture edits push failed ($remoteScanId): $e");
    }
  }

  static void _ensureFurnitureEditsSink() {
    if (_furnitureSinkWired) return;
    _furnitureSinkWired = true;
    RoomUsdzViewer.onFurnitureEditsChanged = (listingId, furnitureEdits) async {
      try {
        await _saveFurnitureEdits(listingId, furnitureEdits);
        final remoteId = _remoteScanIdByListingId[listingId];
        if (remoteId != null && remoteId > 0) {
          await _pushFurnitureEdits(remoteId, furnitureEdits);
        }
      } catch (e) {
        debugPrint("Furniture edits save failed: $e");
      }
    };
  }

  static void _ensureShareSink() {
    if (_shareSinkWired) return;
    _shareSinkWired = true;
    RoomUsdzViewer.onShareTapped = (listingId) {
      final remoteId = _shareScanIdByListingId[listingId] ?? listingId;
      // Fire-and-forget; share sheet is async UI.
      unawaited(
        ScanShareService.shareScan(remoteId, languageCode: _shareLanguageCode),
      );
    };
  }

  /// USDZ is a ZIP (`PK` magic). Reject tiny health-check HTML bodies.
  static bool looksLikeUsdz(File file) {
    try {
      final len = file.lengthSync();
      if (len < 64) return false;
      final raf = file.openSync(mode: FileMode.read);
      try {
        final magic = raf.readSync(2);
        return magic.length == 2 && magic[0] == 0x50 && magic[1] == 0x4b; // PK
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// Resolves a persisted local USDZ path after an iOS app-container move.
  ///
  /// Absolute sandbox paths contain a container UUID. During simulator
  /// reinstalls (and some restore/update flows) iOS can move the app data to a
  /// new UUID while SharedPreferences still contains the previous absolute
  /// path. The relative path below Library/Application Support remains stable.
  static Future<File?> resolveLocalUsdz(
    String? persistedPath, {
    String? fallbackPathOrUrl,
  }) async {
    final raw = persistedPath?.trim();
    final support = await getApplicationSupportDirectory();

    if (raw != null && raw.isNotEmpty) {
      final direct = File(raw);
      if (direct.existsSync() && looksLikeUsdz(direct)) return direct;

      const marker = '/Library/Application Support/';
      final markerIndex = raw.indexOf(marker);
      if (markerIndex >= 0) {
        final relative = raw.substring(markerIndex + marker.length);
        final relocated = File('${support.path}/$relative');
        if (relocated.existsSync() && looksLikeUsdz(relocated)) {
          debugPrint('Recovered relocated USDZ: $raw -> ${relocated.path}');
          return relocated;
        }
      }
    }

    // Project sync intentionally omits device-local paths. Recover a retained
    // model by the stable filename supplied by the remote URL before starting
    // another potentially hundreds-of-megabytes download.
    final fallback = fallbackPathOrUrl?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      final uri = Uri.tryParse(fallback);
      final basename = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : fallback.split('/').last;
      if (basename.toLowerCase().endsWith('.usdz')) {
        final preferred = File('${support.path}/Makon3DTestModels/$basename');
        if (preferred.existsSync() && looksLikeUsdz(preferred)) {
          debugPrint('Recovered cached USDZ by filename: ${preferred.path}');
          return preferred;
        }
        try {
          await for (final entity in support.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is File &&
                entity.uri.pathSegments.last == basename &&
                looksLikeUsdz(entity)) {
              debugPrint('Recovered cached USDZ by filename: ${entity.path}');
              return entity;
            }
          }
        } catch (_) {
          // Cache lookup is best-effort; the remote download remains fallback.
        }
      }
    }
    return null;
  }

  /// Downloads USDZ to the per-scan temp cache (for mini preview or fullscreen).
  /// Returns null on non-iOS. [pathOrUrl] may be relative or absolute.
  ///
  /// Cache is keyed by [scanId] plus a sidecar of the absolute URL so replacing
  /// the remote asset (e.g. RoomPlan → photogrammetry USDZ) re-downloads.
  static Future<File?> downloadUsdToCache(
    String pathOrUrl, {
    required int scanId,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (!isIOSDevice) return null;
    final absolute = ScanUploadService.hostedUrl(pathOrUrl);
    final temp = await getTemporaryDirectory();
    final file = File("${temp.path}/makon3d_scan_$scanId.usdz");
    final urlSidecar = File("${temp.path}/makon3d_scan_$scanId.usdz.url");
    final cachedUrl = urlSidecar.existsSync()
        ? urlSidecar.readAsStringSync().trim()
        : '';
    if (file.existsSync() && looksLikeUsdz(file) && cachedUrl == absolute) {
      // RoomPlan USDZs are ~100–500KB. A multi‑MB cache for a room_scan.usdz URL
      // is leftover photogrammetry from when that scan id briefly pointed at a
      // different asset — reopen would show the wrong (often mis-oriented) mesh.
      final isRoomPlanUrl = absolute.contains('/room_scan.usdz');
      final looksLikePhotogrammetryLeftover =
          isRoomPlanUrl && file.lengthSync() > 5 * 1024 * 1024;
      if (!looksLikePhotogrammetryLeftover) {
        return file;
      }
    }
    if (file.existsSync()) {
      // Stale HTML/error body, URL changed, or RoomPlan cache holding a huge USDZ.
      try {
        await file.delete();
      } catch (_) {}
    }
    try {
      if (urlSidecar.existsSync()) await urlSidecar.delete();
    } catch (_) {}
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        // Photogrammetry USDZ can be hundreds of MB on slow networks.
        receiveTimeout: const Duration(minutes: 20),
        responseType: ResponseType.bytes,
        // Reject HTML health-check / SPA fallbacks that used to return 200.
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final response = await dio.download(
      absolute,
      file.path,
      onReceiveProgress: onReceiveProgress,
    );
    final contentType = response.headers.value('content-type') ?? '';
    if (contentType.contains('text/html') ||
        !file.existsSync() ||
        !looksLikeUsdz(file)) {
      try {
        if (file.existsSync()) await file.delete();
      } catch (_) {}
      throw StateError("Downloaded USDZ is missing, empty, or not a ZIP/USDZ");
    }
    try {
      await urlSidecar.writeAsString(absolute, flush: true);
    } catch (_) {}
    return file;
  }

  /// Downloads a remote USDZ (relative or absolute URL) then presents it.
  static Future<bool> downloadAndPresent(
    String pathOrUrl, {
    required int scanId,
    required String languageCode,
    double? worldPlusXBearingDeg,
    int? shareScanId,
  }) async {
    final file = await downloadUsdToCache(pathOrUrl, scanId: scanId);
    if (file == null) return false;
    return presentLocalFile(
      file.path,
      scanId: scanId,
      languageCode: languageCode,
      worldPlusXBearingDeg: worldPlusXBearingDeg,
      shareScanId: shareScanId,
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
    int? shareScanId,
  }) async {
    if (!isIOSDevice) return false;

    final file = await resolveLocalUsdz(
      localUsdzPath,
      fallbackPathOrUrl: usdzUrl,
    );
    if (file != null) {
      return presentLocalFile(
        file.path,
        scanId: scanId,
        languageCode: languageCode,
        worldPlusXBearingDeg: worldPlusXBearingDeg,
        shareScanId: shareScanId,
      );
    }

    final url = usdzUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return downloadAndPresent(
        url,
        scanId: scanId,
        languageCode: languageCode,
        worldPlusXBearingDeg: worldPlusXBearingDeg,
        shareScanId: shareScanId,
      );
    }

    return false;
  }

  /// Returns true if the native viewer was presented.
  ///
  /// [scanId] is passed to the kit as `listingId` (must resolve to > 0) so
  /// owner-edit chrome (Add furniture, north adjust) is enabled.
  ///
  /// When [shareScanId] is a positive remote API id, the native Share button
  /// is shown and shares GIF + viewer link for that scan.
  static Future<bool> presentLocalFile(
    String path, {
    required int scanId,
    required String languageCode,
    double? worldPlusXBearingDeg,
    Map<String, dynamic>? furnitureEdits,
    int? shareScanId,
  }) async {
    if (!isIOSDevice) return false;
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError("USDZ not found at $path");
    }
    // SceneKit expands JPEG atlases into uncompressed GPU textures. A large
    // photogrammetry USDZ can therefore require several GB while loading and
    // be terminated by iOS before Swift can report an error. Mobile LODs stay
    // below this ceiling; reject an unsafe cached original instead of crashing.
    const maximumSafeViewerFileBytes = 192 * 1024 * 1024;
    if (file.lengthSync() > maximumSafeViewerFileBytes) {
      throw StateError(
        "USDZ is too large for the iOS viewer; a mobile model is required",
      );
    }
    final listingId = viewerListingId(scanId);
    _ensureFurnitureEditsSink();
    final enableShare = shareScanId != null && shareScanId > 0;
    if (enableShare) {
      _shareLanguageCode = languageCode;
      _shareScanIdByListingId[listingId] = shareScanId;
      _ensureShareSink();
    }
    if (shareScanId != null && shareScanId > 0) {
      _remoteScanIdByListingId[listingId] = shareScanId;
    } else if (scanId > 0) {
      _remoteScanIdByListingId[listingId] = scanId;
    }
    final edits =
        furnitureEdits ??
        await loadFurnitureEditsForScan(scanId, remoteScanId: shareScanId);
    String l(String key) => L10n.getForLanguage(key, languageCode);
    final strings = <String, String>{
      "title": l("room_3d_viewer_title"),
      "dimensionsCaption": l("room_3d_dimensions_caption"),
      "dimensionsLine1Template": l("room_3d_dimensions_line1_template"),
      "dimensionsHeightTemplate": l("room_3d_dimensions_height_template"),
      "dimensionsLine2Template": l("room_3d_dimensions_line2_template"),
      "structureWindowsTemplate": l("room_3d_structure_windows_template"),
      "structureDoorsTemplate": l("room_3d_structure_doors_template"),
      "structureWallAreaTemplate": l("room_3d_structure_wall_area_template"),
      "loadErrorTitle": l("room_3d_load_error_title"),
      "alertOk": l("ok"),
      "back": l("back"),
      "share": l("share_3d_scan_title"),
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
      "floorPlanAdjustNorthMessage": l(
        "room_3d_floor_plan_adjust_north_message",
      ),
      "floorPlanAdjustNorthReset": l("room_3d_floor_plan_adjust_north_reset"),
      "floorPlanAdjustNorthUpdated": l(
        "room_3d_floor_plan_adjust_north_updated",
      ),
      "floorPlanAdjustNorthDegreesFormat": l(
        "room_3d_floor_plan_adjust_north_degrees_format",
      ),
      "floorPlanRotateFurnitureTitle": l(
        "room_3d_floor_plan_rotate_furniture_title",
      ),
      "floorPlanRotateFurnitureMessage": l(
        "room_3d_floor_plan_rotate_furniture_message",
      ),
      "floorPlanRotateFurnitureUpdated": l(
        "room_3d_floor_plan_rotate_furniture_updated",
      ),
      "floorPlanRotateFurnitureDegreesFormat": l(
        "room_3d_floor_plan_rotate_furniture_degrees_format",
      ),
      "floorPlanMoveFurnitureUp": l("room_3d_floor_plan_move_furniture_up"),
      "floorPlanMoveFurnitureDown": l("room_3d_floor_plan_move_furniture_down"),
      "floorPlanMoveFurnitureLeft": l("room_3d_floor_plan_move_furniture_left"),
      "floorPlanMoveFurnitureRight": l(
        "room_3d_floor_plan_move_furniture_right",
      ),
      "floorPlanRaiseFurniture": l("room_3d_floor_plan_raise_furniture"),
      "floorPlanLowerFurniture": l("room_3d_floor_plan_lower_furniture"),
      "floorPlanFurnitureVariantTitle": l(
        "room_3d_floor_plan_furniture_variant_title",
      ),
      "floorPlanFurnitureVariantAccessibility": l(
        "room_3d_floor_plan_furniture_variant_accessibility",
      ),
      "floorPlanFurnitureRotationTitle": l(
        "room_3d_floor_plan_furniture_rotation_title",
      ),
      "floorPlanFurnitureColorTitle": l(
        "room_3d_floor_plan_furniture_color_title",
      ),
      "floorPlanFurnitureColorPartTitle": l(
        "room_3d_floor_plan_furniture_color_part_title",
      ),
      "floorPlanFurnitureColorRoleFrame": l(
        "room_3d_floor_plan_furniture_color_role_frame",
      ),
      "floorPlanFurnitureColorRoleFabric": l(
        "room_3d_floor_plan_furniture_color_role_fabric",
      ),
      "floorPlanFurnitureColorRoleLinen": l(
        "room_3d_floor_plan_furniture_color_role_linen",
      ),
      "floorPlanFurnitureColorDefault": l(
        "room_3d_floor_plan_furniture_color_default",
      ),
      "floorPlanFurnitureColorAccessibility": l(
        "room_3d_floor_plan_furniture_color_accessibility",
      ),
      "floorPlanDeleteFurniture": l("room_3d_floor_plan_delete_furniture"),
      "floorPlanDeleteFurnitureConfirmTitle": l(
        "room_3d_floor_plan_delete_furniture_confirm_title",
      ),
      "floorPlanDeleteFurnitureConfirmMessage": l(
        "room_3d_floor_plan_delete_furniture_confirm_message",
      ),
      "floorPlanDeleteFurnitureUpdated": l(
        "room_3d_floor_plan_delete_furniture_updated",
      ),
      "floorPlanFurnitureSizeTitle": l(
        "room_3d_floor_plan_furniture_size_title",
      ),
      "floorPlanFurnitureSizeWidth": l(
        "room_3d_floor_plan_furniture_size_width",
      ),
      "floorPlanFurnitureSizeLength": l(
        "room_3d_floor_plan_furniture_size_length",
      ),
      "floorPlanFurnitureSizeHeight": l(
        "room_3d_floor_plan_furniture_size_height",
      ),
      "floorPlanFurnitureSizeMetersFormat": l(
        "room_3d_floor_plan_furniture_size_meters_format",
      ),
      "floorPlanAddFurniture": l("room_3d_floor_plan_add_furniture"),
      "floorPlanAddFurnitureTitle": l("room_3d_floor_plan_add_furniture_title"),
      "floorPlanAddFurnitureUpdated": l(
        "room_3d_floor_plan_add_furniture_updated",
      ),
      "floorPlanChangeWalls": l("room_3d_floor_plan_change_walls"),
      "floorPlanChangeFloor": l("room_3d_floor_plan_change_floor"),
      "floorPlanChangeWallsTitle": l("room_3d_floor_plan_change_walls_title"),
      "floorPlanChangeFloorTitle": l("room_3d_floor_plan_change_floor_title"),
      "floorPlanFloorTint": l("room_3d_floor_plan_floor_tint"),
      "floorPlanWallBrick": l("room_3d_floor_plan_wall_brick"),
      "floorPlanWallPlaster": l("room_3d_floor_plan_wall_plaster"),
      "floorPlanWallPainted": l("room_3d_floor_plan_wall_painted"),
      "floorPlanWallConcrete": l("room_3d_floor_plan_wall_concrete"),
      "floorPlanFloorWoodTile": l("room_3d_floor_plan_floor_wood_tile"),
      "floorPlanFloorLaminate": l("room_3d_floor_plan_floor_laminate"),
      "floorPlanFloorCeramicTile": l("room_3d_floor_plan_floor_ceramic_tile"),
      "floorPlanFloorCarpet": l("room_3d_floor_plan_floor_carpet"),
      "floorPlanSurfacesUpdated": l("room_3d_floor_plan_surfaces_updated"),
      "floorPlanEditDimensionTitle": l(
        "room_3d_floor_plan_edit_dimension_title",
      ),
      "floorPlanEditDimensionCurrent": l(
        "room_3d_floor_plan_edit_dimension_current",
      ),
      "floorPlanEditDimensionNewValue": l(
        "room_3d_floor_plan_edit_dimension_new_value",
      ),
      "floorPlanEditDimensionCancel": l(
        "room_3d_floor_plan_edit_dimension_cancel",
      ),
      "floorPlanEditDimensionApply": l(
        "room_3d_floor_plan_edit_dimension_apply",
      ),
      "floorPlanEditDimensionUpdated": l(
        "room_3d_floor_plan_edit_dimension_updated",
      ),
      "floorPlanEditDimensionLargeChangeTitle": l(
        "room_3d_floor_plan_edit_dimension_large_change_title",
      ),
      "floorPlanEditDimensionLargeChangeMessage": l(
        "room_3d_floor_plan_edit_dimension_large_change_message",
      ),
      "floorPlanEditDimensionInvalidTitle": l(
        "room_3d_floor_plan_edit_dimension_invalid_title",
      ),
      "floorPlanEditDimensionInvalidMessage": l(
        "room_3d_floor_plan_edit_dimension_invalid_message",
      ),
      "floorPlanEditDimensionConfirmLargeChange": l(
        "room_3d_floor_plan_edit_dimension_confirm_large_change",
      ),
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
      "floorPlanPlumbing": l("room_3d_floor_plan_plumbing"),
      "floorPlanObjectBathtub": l("room_3d_floor_plan_object_bathtub"),
      "floorPlanObjectToilet": l("room_3d_floor_plan_object_toilet"),
      "floorPlanObjectSink": l("room_3d_floor_plan_object_sink"),
      "floorPlanObjectDoor": l("room_3d_floor_plan_object_door"),
      "floorPlanObjectWindow": l("room_3d_floor_plan_object_window"),
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
      listingId: listingId,
      isListingOwner: true,
      shareEnabled: enableShare,
      worldPlusXBearingDeg: worldPlusXBearingDeg,
      furnitureEdits: edits,
    );
  }
}
