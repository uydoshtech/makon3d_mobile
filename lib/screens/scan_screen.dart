import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_roomplan/flutter_roomplan.dart";
import "package:permission_handler/permission_handler.dart";

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

/// The single screen of Makon 3D: RoomPlan (LiDAR) capture → upload USDZ to
/// the backend → present the native 3D viewer with the fresh scan.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _roomPlan = FlutterRoomplan();
  static const MethodChannel _roomplanChannel =
      MethodChannel("rkg/flutter_roomplan");

  /// The RoomPlan plugin keeps the last capture-finished handler in a
  /// singleton; clear it on dispose so this [State] is not retained.
  bool _registeredRoomCaptureCallback = false;
  bool _uploading = false;
  bool _starting = false;

  /// Null until [RoomPlanCapability.isSupportedOnDevice] resolves on iOS.
  bool? _roomPlanSupported;

  String? _lastScanPath;
  double? _lastScanBearingDeg;

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
  }

  @override
  void dispose() {
    if (_registeredRoomCaptureCallback) {
      _roomPlan.onRoomCaptureFinished(() {});
    }
    _iconRotationController.dispose();
    super.dispose();
  }

  Future<void> _resolveSupportAndRegisterCapture() async {
    final supported = await RoomPlanCapability.isSupportedOnDevice();
    if (!mounted) return;
    setState(() => _roomPlanSupported = supported);
    if (!supported) return;
    _registerRoomCaptureCallback();
  }

  void _registerRoomCaptureCallback() {
    if (_registeredRoomCaptureCallback) return;
    _registeredRoomCaptureCallback = true;
    _roomPlan.onRoomCaptureFinished(() {
      unawaited(_handleCaptureFinished());
    });
  }

  Future<void> _handleCaptureFinished() async {
    final path = await _roomPlan.getUsdzFilePath();
    if (!mounted) return;
    if (path == null || path.isEmpty) {
      // RoomPlan invokes onRoomCaptureFinished on Cancel too, with no USDZ.
      Toasts.showInfo(context, L10n.get("room_scan_cancelled"));
      return;
    }
    setState(() => _uploading = true);
    try {
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
      ScansRefreshNotifier.instance.notifyScansChanged();
      if (!mounted) return;
      setState(() {
        _lastScanPath = path;
        _lastScanBearingDeg = uploadedMetrics?.worldPlusXBearingDeg;
        _uploading = false;
      });
      Toasts.showSuccess(context, L10n.get("room_scan_success"));
      await _presentViewer(path, uploadedMetrics?.worldPlusXBearingDeg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      final msg = e.toString();
      final isTooLarge = msg.contains("File too large") ||
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
      });
    }
  }

  Future<void> _presentViewer(String path, double? bearingDeg) async {
    await RoomUsdzViewerService.presentLocalFile(
      path,
      languageCode: LanguageState().currentLanguage,
      worldPlusXBearingDeg: bearingDeg,
    );
  }

  Future<void> _startScan() async {
    if (!isIOSDevice) return;
    setState(() => _starting = true);
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

      await _roomplanChannel.invokeMethod<void>("startScan", <String, dynamic>{
        "enableMultiRoom": true,
        "strings": <String, String>{
          "cancel": L10n.get("cancel"),
          "done": L10n.get("done"),
          "finish": L10n.get("room_scan_finish"),
          "scanOtherRooms": L10n.get("room_scan_scan_other_rooms"),
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
              ],
            )
          else ...[
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
