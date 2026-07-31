import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_roomplan/flutter_roomplan.dart";
import "package:permission_handler/permission_handler.dart";
import "package:room_scan_kit/photogrammetry_upload.dart";

import "package:makon3d_mobile/base/ios_device.dart";
import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/models/room_scan_metrics.dart";
import "package:makon3d_mobile/services/native_language_service.dart";
import "package:makon3d_mobile/services/room_plan_capability.dart";
import "package:makon3d_mobile/services/room_scan_bounds_service.dart";
import "package:makon3d_mobile/services/room_usdz_viewer_service.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";
import "package:makon3d_mobile/services/scans_refresh_notifier.dart";
import "package:makon3d_mobile/widgets/toasts.dart";

/// RoomPlan (LiDAR) capture → upload USDZ to the backend.
///
/// On success, [onScanUploaded] is invoked so the shell can switch to the
/// Scans list (where the user can open the 3D/2D viewer).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.onScanUploaded});

  /// Called after a successful upload (before UI settles on the list tab).
  final VoidCallback? onScanUploaded;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _roomPlan = FlutterRoomplan();
  static const MethodChannel _roomplanChannel = MethodChannel(
    "rkg/flutter_roomplan",
  );

  /// The RoomPlan plugin keeps the last capture-finished handler in a
  /// singleton; clear it on dispose so this [State] is not retained.
  bool _registeredRoomCaptureCallback = false;
  bool _uploading = false;
  bool _starting = false;
  bool _photogrammetryEnabled = false;
  Completer<int>? _photogrammetryTarget;

  /// Null until [RoomPlanCapability.isSupportedOnDevice] resolves on iOS.
  bool? _roomPlanSupported;

  String? _lastScanPath;
  double? _lastScanBearingDeg;
  int? _lastScanId;

  /// Set only after a successful API upload (enables Share + GIF).
  int? _lastRemoteScanId;

  late final AnimationController _iconRotationController;
  late final Animation<double> _iconRotationAnimation;

  @override
  void initState() {
    super.initState();

    // 6-second attention burst (2 full rotations), then static.
    _iconRotationController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..forward();
    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _iconRotationController, curve: Curves.linear),
    );

    if (!isIOSDevice) {
      _roomPlanSupported = false;
      return;
    }
    unawaited(_resolveSupportAndRegisterCapture());
    PhotogrammetryUpload.instance.listen(
      _keepPhotogrammetryPackageLocal,
      onPackageFailed: _handlePhotogrammetryPackageFailure,
    );
    unawaited(
      PhotogrammetryPreference.load().then((value) {
        if (mounted) setState(() => _photogrammetryEnabled = value);
      }),
    );
  }

  @override
  void dispose() {
    if (_registeredRoomCaptureCallback) {
      _roomPlan.onRoomCaptureFinished(() {});
    }
    _iconRotationController.dispose();
    PhotogrammetryUpload.instance.stopListening();
    super.dispose();
  }

  Future<void> _keepPhotogrammetryPackageLocal(String path) async {
    debugPrint(
      '[Photogrammetry] Automatic server upload disabled; '
      'keeping local archive: $path',
    );
    try {
      final scanId =
          await (_photogrammetryTarget?.future ??
                  Future<int>.error(StateError('Missing scan target')))
              .timeout(const Duration(minutes: 8));
      await PhotogrammetryLocalPackageStore.instance.save(
        PhotogrammetryLocalPackage(
          packagePath: path,
          targetType: 'makon3d_scan',
          targetId: scanId,
          savedAt: DateTime.now().toUtc(),
          state: 'pending',
        ),
      );
      debugPrint(
        '[Photogrammetry] Local archive associated with scanId=$scanId; '
        'server upload skipped',
      );
    } catch (error) {
      debugPrint(
        '[Photogrammetry] Could not associate local archive yet: $error',
      );
    }
  }

  void _handlePhotogrammetryPackageFailure(String error) {
    debugPrint('Photogrammetry package failed: $error');
    if (mounted) {
      Toasts.showError(
        context,
        '${L10n.get('room_scan_photogrammetry_retry_missing')}: $error',
      );
    }
  }

  Future<void> _resolveSupportAndRegisterCapture() async {
    final supported = await RoomPlanCapability.isSupportedOnDevice();
    if (!mounted) return;
    setState(() => _roomPlanSupported = supported);
    if (!supported) return;
    _registerRoomCaptureCallback();
  }

  void _registerRoomCaptureCallback() {
    _registeredRoomCaptureCallback = true;
    _roomPlan.onRoomCaptureFinished(() {
      unawaited(_handleCaptureFinished());
    });
  }

  Future<void> _handleCaptureFinished() async {
    debugPrint('[RoomScan] Native completion callback received');
    final path = await _roomPlan.getUsdzFilePath();
    debugPrint('[RoomScan] Completed USDZ path: $path');
    if (!mounted) return;
    if (path == null || path.isEmpty) {
      // RoomPlan invokes onRoomCaptureFinished on Cancel too, with no USDZ.
      Toasts.showInfo(context, L10n.get("room_scan_cancelled"));
      return;
    }
    setState(() => _uploading = true);
    try {
      debugPrint('[RoomScan] Starting standard model upload');
      var metrics = await RoomScanBoundsService.computeFromUsdPath(path);
      RoomScanMetrics? uploadedMetrics = metrics;
      final result = await ScanUploadService.uploadScan(
        usdzFilePath: path,
        metrics: metrics,
      );
      // RoomPlan may finish writing the USDZ slightly after the callback;
      // retry the bounds computation once more for the viewer if it failed.
      metrics ??= await RoomScanBoundsService.computeFromUsdPath(path);
      uploadedMetrics ??= metrics;
      debugPrint("Scan uploaded: id=${result.id} glb=${result.glbUrl}");
      if (!(_photogrammetryTarget?.isCompleted ?? true)) {
        _photogrammetryTarget!.complete(result.id);
      }
      final latestPackage = await PhotogrammetryLocalPackageStore.instance
          .latestPath();
      if (latestPackage != null) {
        await PhotogrammetryLocalPackageStore.instance.save(
          PhotogrammetryLocalPackage(
            packagePath: latestPackage,
            targetType: 'makon3d_scan',
            targetId: result.id,
            savedAt: DateTime.now().toUtc(),
            state: 'pending',
          ),
        );
      }
      ScansRefreshNotifier.instance.notifyScansChanged();
      if (!mounted) return;
      setState(() {
        _lastScanPath = path;
        _lastScanBearingDeg = uploadedMetrics?.worldPlusXBearingDeg;
        _lastScanId = result.id;
        _lastRemoteScanId = result.id;
        _uploading = false;
      });
      Toasts.showSuccess(context, L10n.get("room_scan_success"));
      // Hand off to the Scans list — user opens the model from there.
      widget.onScanUploaded?.call();
      debugPrint(
        '[RoomScan] Standard USDZ upload complete; '
        'photogrammetry archive stays local',
      );
    } catch (e) {
      debugPrint('[RoomScan] Standard upload failed: $e');
      if (!mounted) return;
      setState(() => _uploading = false);
      final msg = e.toString();
      final isTooLarge =
          msg.contains("File too large") ||
          msg.contains("413") ||
          msg.contains("Payload Too Large");
      Toasts.showError(
        context,
        isTooLarge
            ? L10n.get("room_scan_too_large")
            : L10n.get("room_scan_error"),
      );
      // Keep the local scan viewable even when the upload failed.
      setState(() {
        _lastScanPath = path;
        _lastScanId = path.hashCode;
        _lastRemoteScanId = null;
      });
    }
  }

  Future<void> _presentViewer(String path, double? bearingDeg) async {
    await RoomUsdzViewerService.presentLocalFile(
      path,
      scanId: _lastScanId ?? path.hashCode,
      languageCode: LanguageState().currentLanguage,
      worldPlusXBearingDeg: bearingDeg,
      shareScanId: _lastRemoteScanId,
    );
  }

  Future<void> _startScan() async {
    if (!isIOSDevice) return;
    setState(() {
      _starting = true;
      _photogrammetryTarget = _photogrammetryEnabled ? Completer<int>() : null;
    });
    try {
      // Best-effort: re-apply `AppleLanguages` right before touching RoomPlan
      // so the native coaching overlay follows the in-app language (guaranteed
      // from the next cold launch onward; see AppDelegate).
      await NativeLanguageService.setPreferredLanguage(
        LanguageState().currentLanguage,
      );

      final supported = await _roomPlan.isSupported();
      if (!supported) {
        if (!mounted) return;
        Toasts.showError(context, L10n.get("room_scan_not_supported"));
        return;
      }

      // Request the camera here so the system dialog appears over this
      // Flutter screen instead of on top of the black native capture UI.
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (!mounted) return;
        Toasts.showInfo(context, L10n.get("room_scan_camera_required"));
        return;
      }
      if (!mounted) return;

      // flutter_roomplan owns a single global completion handler. Re-arm it
      // immediately before presenting RoomPlan so another scan screen's
      // lifecycle cannot leave this capture wired to a stale/empty callback.
      _registerRoomCaptureCallback();
      await _roomplanChannel.invokeMethod<void>("startScan", <String, dynamic>{
        // Single-room only: hide the post-scan "Scan Other Rooms" button.
        "enableMultiRoom": false,
        "enablePhotogrammetry": _photogrammetryEnabled,
        "strings": <String, String>{
          "cancel": L10n.get("cancel"),
          "done": L10n.get("done"),
          "finish": L10n.get("room_scan_finish"),
          // Live detection HUD (native RoomCapture overlay).
          "roomplan_stats_walls": L10n.get("room_scan_stats_walls"),
          "roomplan_stats_doors": L10n.get("room_scan_stats_doors"),
          "roomplan_stats_windows": L10n.get("room_scan_stats_windows"),
          "roomplan_stats_objects": L10n.get("room_scan_stats_objects"),
          "roomplan_compass": L10n.get("room_scan_compass"),
          "roomplan_stats_television": L10n.get("room_scan_stats_television"),
          "roomplan_stats_storage": L10n.get("room_scan_stats_storage"),
          "roomplan_stats_cabinet": L10n.get("room_scan_stats_cabinet"),
          "roomplan_stats_sofa": L10n.get("room_scan_stats_sofa"),
          "roomplan_stats_bed": L10n.get("room_scan_stats_bed"),
          "roomplan_stats_table": L10n.get("room_scan_stats_table"),
          "roomplan_stats_chair": L10n.get("room_scan_stats_chair"),
          "roomplan_stats_refrigerator": L10n.get(
            "room_scan_stats_refrigerator",
          ),
          "roomplan_stats_sink": L10n.get("room_scan_stats_sink"),
          "roomplan_stats_toilet": L10n.get("room_scan_stats_toilet"),
          "roomplan_stats_bathtub": L10n.get("room_scan_stats_bathtub"),
          "roomplan_stats_oven": L10n.get("room_scan_stats_oven"),
          "roomplan_stats_stove": L10n.get("room_scan_stats_stove"),
          "roomplan_stats_dishwasher": L10n.get("room_scan_stats_dishwasher"),
          "roomplan_stats_washer_dryer": L10n.get(
            "room_scan_stats_washer_dryer",
          ),
          "roomplan_stats_fireplace": L10n.get("room_scan_stats_fireplace"),
          "roomplan_stats_stairs": L10n.get("room_scan_stats_stairs"),
          "roomplan_stats_object": L10n.get("room_scan_stats_object"),
          "roomplan_detected_wall": L10n.get("room_scan_detected_wall"),
          "roomplan_detected_door": L10n.get("room_scan_detected_door"),
          "roomplan_detected_window": L10n.get("room_scan_detected_window"),
          "roomplan_detected_storage": L10n.get("room_scan_detected_storage"),
          "roomplan_detected_cabinet": L10n.get("room_scan_detected_cabinet"),
          "roomplan_detected_bed": L10n.get("room_scan_detected_bed"),
          "roomplan_detected_sofa": L10n.get("room_scan_detected_sofa"),
          "roomplan_detected_table": L10n.get("room_scan_detected_table"),
          "roomplan_detected_chair": L10n.get("room_scan_detected_chair"),
          "roomplan_detected_television": L10n.get(
            "room_scan_detected_television",
          ),
          "roomplan_detected_refrigerator": L10n.get(
            "room_scan_detected_refrigerator",
          ),
          "roomplan_detected_sink": L10n.get("room_scan_detected_sink"),
          "roomplan_detected_toilet": L10n.get("room_scan_detected_toilet"),
          "roomplan_detected_bathtub": L10n.get("room_scan_detected_bathtub"),
          "roomplan_detected_oven": L10n.get("room_scan_detected_oven"),
          "roomplan_detected_stove": L10n.get("room_scan_detected_stove"),
          "roomplan_detected_dishwasher": L10n.get(
            "room_scan_detected_dishwasher",
          ),
          "roomplan_detected_washer_dryer": L10n.get(
            "room_scan_detected_washer_dryer",
          ),
          "roomplan_detected_fireplace": L10n.get(
            "room_scan_detected_fireplace",
          ),
          "roomplan_detected_stairs": L10n.get("room_scan_detected_stairs"),
          "roomplan_detected_object": L10n.get("room_scan_detected_object"),
          // Post-scan results card (grey model screen).
          "roomplan_results_perimeter": L10n.get("room_scan_results_perimeter"),
          "roomplan_results_floor_area": L10n.get(
            "room_scan_results_floor_area",
          ),
          "roomplan_results_wall_area": L10n.get("room_scan_results_wall_area"),
          "roomplan_results_windows": L10n.get("room_scan_results_windows"),
          "roomplan_results_doors": L10n.get("room_scan_results_doors"),
          "roomplan_results_height": L10n.get("room_scan_results_height"),
          "roomplan_quality_overlay": L10n.get("room_scan_quality_overlay"),
          "roomplan_scan_quality": L10n.get("room_scan_scan_quality"),
        },
      });
    } on MissingPluginException {
      if (!mounted) return;
      Toasts.showError(context, L10n.get("room_scan_error"));
    } on PlatformException {
      if (!mounted) return;
      Toasts.showError(context, L10n.get("room_scan_error"));
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get("room_scan_error"));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Widget _buildLanguageMenu() {
    const names = <String, String>{
      "uz": "O'zbekcha",
      "ru": "Русский",
      "en": "English",
    };
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      initialValue: LanguageState().currentLanguage,
      onSelected: (code) => unawaited(LanguageState().setLanguage(code)),
      itemBuilder: (context) => [
        for (final locale in supportedLocales)
          PopupMenuItem<String>(
            value: locale.languageCode,
            child: Text(names[locale.languageCode] ?? locale.languageCode),
          ),
      ],
    );
  }

  Widget _buildRotating3dIcon(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: L10n.get("room_scan_title"),
      child: AnimatedBuilder(
        animation: _iconRotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _iconRotationAnimation.value * 2 * math.pi,
            child: child,
          );
        },
        child: Icon(
          Icons.view_in_ar,
          size: 190,
          color: iconColor.withValues(alpha: 0.92),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_roomPlanSupported == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_roomPlanSupported == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            L10n.get("room_scan_not_supported"),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final loading = _uploading || _starting;

    return SingleChildScrollView(
      // Extra bottom inset so the Start button clears the curved nav bar.
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.get("room_scan_instructions"),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (!_uploading) ...[
            const SizedBox(height: 28),
            Center(child: _buildRotating3dIcon(context)),
            const SizedBox(height: 28),
          ],
          const SizedBox(height: 24),
          if (_uploading)
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Center(child: Text(L10n.get("room_scan_uploading"))),
                const SizedBox(height: 16),
              ],
            )
          else ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(L10n.get('room_scan_photogrammetry_title')),
              subtitle: Text(L10n.get('room_scan_photogrammetry_subtitle')),
              value: _photogrammetryEnabled,
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() => _photogrammetryEnabled = value);
                      unawaited(PhotogrammetryPreference.save(value));
                    },
            ),
            if (_lastScanPath != null) ...[
              Center(
                child: TextButton.icon(
                  onPressed: loading
                      ? null
                      : () => unawaited(
                          _presentViewer(_lastScanPath!, _lastScanBearingDeg),
                        ),
                  icon: const Icon(Icons.threed_rotation),
                  label: Text(L10n.get("room_scan_view_last")),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: loading ? null : _startScan,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: _starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.view_in_ar, size: 18),
              label: Text(L10n.get("room_scan_start")),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get("room_scan_title")),
        actions: [_buildLanguageMenu()],
      ),
      body: _buildBody(context),
    );
  }
}
