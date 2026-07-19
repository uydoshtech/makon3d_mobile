import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_roomplan/flutter_roomplan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/base/ios_device.dart';
import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/models/room_type.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/services/native_language_service.dart';
import 'package:makon3d_mobile/services/room_plan_capability.dart';
import 'package:makon3d_mobile/services/room_scan_bounds_service.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';
import 'package:makon3d_mobile/services/scans_refresh_notifier.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Shared RoomPlan capture for a Makon project (entire housing or one room).
///
/// Failure of the current room/upload must not wipe previously saved rooms.
class ProjectCaptureScreen extends StatefulWidget {
  const ProjectCaptureScreen({
    required this.projectId,
    required this.mode,
    this.roomId,
    this.roomType,
    super.key,
  });

  final String projectId;
  final ScanMode mode;
  final String? roomId;
  final RoomType? roomType;

  @override
  State<ProjectCaptureScreen> createState() => _ProjectCaptureScreenState();
}

class _ProjectCaptureScreenState extends State<ProjectCaptureScreen> {
  final _roomPlan = FlutterRoomplan();
  static const MethodChannel _roomplanChannel =
      MethodChannel('rkg/flutter_roomplan');

  bool _registeredRoomCaptureCallback = false;
  bool _uploading = false;
  bool _starting = false;
  bool? _roomPlanSupported;

  @override
  void initState() {
    super.initState();
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

  String _newId() {
    final r = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final b = List.generate(6, (_) => r.nextInt(16).toRadixString(16)).join();
    return '$a-$b';
  }

  Future<void> _handleCaptureFinished() async {
    final path = await _roomPlan.getUsdzFilePath();
    if (!mounted) return;
    if (path == null || path.isEmpty) {
      Toasts.showInfo(context, L10n.get('room_scan_cancelled'));
      return;
    }

    final project = MakonProjectStore.instance.getById(widget.projectId);
    if (project == null) {
      Toasts.showError(context, L10n.get('project_not_found'));
      return;
    }

    setState(() => _uploading = true);
    try {
      var metrics = await RoomScanBoundsService.computeFromUsdPath(path);
      final upload = await ScanUploadService.uploadScan(
        usdzFilePath: path,
        metrics: metrics,
      );
      metrics ??= await RoomScanBoundsService.computeFromUsdPath(path);

      final housing = HousingScan(
        id: _newId(),
        localUsdzPath: path,
        remoteScanId: upload.id,
        usdzUrl: upload.usdzUrl,
        glbUrl: upload.glbUrl,
        floorLongM: metrics?.floorLongM,
        floorShortM: metrics?.floorShortM,
        heightM: metrics?.heightM,
        floorAreaM2: metrics?.floorAreaM2,
        worldPlusXBearingDeg: metrics?.worldPlusXBearingDeg,
        capturedAt: DateTime.now(),
      );

      final updated = switch (widget.mode) {
        ScanMode.entireHousing => project.copyWith(entireHousingScan: housing),
        ScanMode.roomByRoom => _attachRoomScan(project, housing),
      };

      await MakonProjectStore.instance.upsert(updated);
      ScansRefreshNotifier.instance.notifyScansChanged();

      if (!mounted) return;
      Toasts.showSuccess(context, L10n.get('room_scan_success'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      final msg = e.toString();
      final isTooLarge = msg.contains('File too large') ||
          msg.contains('413') ||
          msg.contains('Payload Too Large');
      Toasts.showError(
        context,
        isTooLarge
            ? L10n.get('room_scan_too_large')
            : L10n.get('room_scan_error'),
      );
    }
  }

  MakonProject _attachRoomScan(MakonProject project, HousingScan housing) {
    final rooms = List<ProjectRoom>.of(project.rooms);
    if (widget.roomId != null) {
      final index = rooms.indexWhere((r) => r.id == widget.roomId);
      if (index >= 0) {
        rooms[index] = rooms[index].copyWith(scan: housing);
        return project.copyWith(rooms: rooms);
      }
    }
    final type = widget.roomType ?? RoomType.other;
    rooms.add(
      ProjectRoom(
        id: _newId(),
        roomType: type,
        createdAt: DateTime.now(),
        name: L10n.get(type.titleKey),
        scan: housing,
      ),
    );
    return project.copyWith(rooms: rooms);
  }

  Future<void> _startScan() async {
    if (!isIOSDevice) return;
    setState(() => _starting = true);
    try {
      await NativeLanguageService.setPreferredLanguage(
        LanguageState().currentLanguage,
      );

      final supported = await _roomPlan.isSupported();
      if (!supported) {
        if (!mounted) return;
        Toasts.showError(context, L10n.get('room_scan_not_supported'));
        return;
      }

      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (!mounted) return;
        Toasts.showInfo(context, L10n.get('room_scan_camera_required'));
        return;
      }
      if (!mounted) return;

      await _roomplanChannel.invokeMethod<void>('startScan', <String, dynamic>{
        'enableMultiRoom': false,
        'strings': <String, String>{
          'cancel': L10n.get('cancel'),
          'done': L10n.get('done'),
          'finish': L10n.get('room_scan_finish'),
          'roomplan_stats_walls': L10n.get('room_scan_stats_walls'),
          'roomplan_stats_doors': L10n.get('room_scan_stats_doors'),
          'roomplan_stats_windows': L10n.get('room_scan_stats_windows'),
          'roomplan_stats_objects': L10n.get('room_scan_stats_objects'),
          'roomplan_compass': L10n.get('room_scan_compass'),
          'roomplan_stats_television': L10n.get('room_scan_stats_television'),
          'roomplan_stats_storage': L10n.get('room_scan_stats_storage'),
          'roomplan_stats_cabinet': L10n.get('room_scan_stats_cabinet'),
          'roomplan_stats_sofa': L10n.get('room_scan_stats_sofa'),
          'roomplan_stats_bed': L10n.get('room_scan_stats_bed'),
          'roomplan_stats_table': L10n.get('room_scan_stats_table'),
          'roomplan_stats_chair': L10n.get('room_scan_stats_chair'),
          'roomplan_stats_refrigerator':
              L10n.get('room_scan_stats_refrigerator'),
          'roomplan_stats_sink': L10n.get('room_scan_stats_sink'),
          'roomplan_stats_toilet': L10n.get('room_scan_stats_toilet'),
          'roomplan_stats_bathtub': L10n.get('room_scan_stats_bathtub'),
          'roomplan_stats_oven': L10n.get('room_scan_stats_oven'),
          'roomplan_stats_stove': L10n.get('room_scan_stats_stove'),
          'roomplan_stats_dishwasher': L10n.get('room_scan_stats_dishwasher'),
          'roomplan_stats_washer_dryer':
              L10n.get('room_scan_stats_washer_dryer'),
          'roomplan_stats_fireplace': L10n.get('room_scan_stats_fireplace'),
          'roomplan_stats_stairs': L10n.get('room_scan_stats_stairs'),
          'roomplan_stats_object': L10n.get('room_scan_stats_object'),
          'roomplan_detected_wall': L10n.get('room_scan_detected_wall'),
          'roomplan_detected_door': L10n.get('room_scan_detected_door'),
          'roomplan_detected_window': L10n.get('room_scan_detected_window'),
          'roomplan_detected_storage': L10n.get('room_scan_detected_storage'),
          'roomplan_detected_cabinet': L10n.get('room_scan_detected_cabinet'),
          'roomplan_detected_bed': L10n.get('room_scan_detected_bed'),
          'roomplan_detected_sofa': L10n.get('room_scan_detected_sofa'),
          'roomplan_detected_table': L10n.get('room_scan_detected_table'),
          'roomplan_detected_chair': L10n.get('room_scan_detected_chair'),
          'roomplan_detected_television':
              L10n.get('room_scan_detected_television'),
          'roomplan_detected_refrigerator':
              L10n.get('room_scan_detected_refrigerator'),
          'roomplan_detected_sink': L10n.get('room_scan_detected_sink'),
          'roomplan_detected_toilet': L10n.get('room_scan_detected_toilet'),
          'roomplan_detected_bathtub': L10n.get('room_scan_detected_bathtub'),
          'roomplan_detected_oven': L10n.get('room_scan_detected_oven'),
          'roomplan_detected_stove': L10n.get('room_scan_detected_stove'),
          'roomplan_detected_dishwasher':
              L10n.get('room_scan_detected_dishwasher'),
          'roomplan_detected_washer_dryer':
              L10n.get('room_scan_detected_washer_dryer'),
          'roomplan_detected_fireplace':
              L10n.get('room_scan_detected_fireplace'),
          'roomplan_detected_stairs': L10n.get('room_scan_detected_stairs'),
          'roomplan_detected_object': L10n.get('room_scan_detected_object'),
        },
      });
    } on MissingPluginException {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('room_scan_error'));
    } on PlatformException {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('room_scan_error'));
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('room_scan_error'));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _uploading || _starting;
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get('room_scan_title')),
      ),
      body: _roomPlanSupported == null
          ? const Center(child: CircularProgressIndicator())
          : _roomPlanSupported == false
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      L10n.get('room_scan_not_supported'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        L10n.get('room_scan_instructions'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      if (_uploading)
                        Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(L10n.get('room_scan_uploading')),
                          ],
                        )
                      else
                        FilledButton.icon(
                          onPressed: loading ? null : _startScan,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: _starting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.view_in_ar),
                          label: Text(L10n.get('room_scan_start')),
                        ),
                    ],
                  ),
                ),
    );
  }
}
