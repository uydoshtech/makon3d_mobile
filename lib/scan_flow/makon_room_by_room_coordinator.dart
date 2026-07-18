import 'package:flutter/material.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/room_type.dart';
import 'package:makon3d_mobile/screens/project_capture_screen.dart';
import 'package:makon3d_mobile/screens/room_type_selection_screen.dart';
import 'package:makon3d_mobile/services/makon_analytics.dart';

/// Orchestrates Makon room-by-room capture: pick type → scan → save room.
class MakonRoomByRoomCoordinator implements ScanFlowCoordinator {
  MakonRoomByRoomCoordinator({
    required this.context,
    required this.project,
    this.entryPoint = 'project_dashboard',
    this.existingRoomId,
  });

  final BuildContext context;
  final MakonProject project;
  final String entryPoint;
  final String? existingRoomId;

  bool _cancelled = false;

  @override
  Future<void> start() async {
    _cancelled = false;
    MakonAnalytics.roomByRoomStarted(
      projectId: project.id,
      entryPoint: entryPoint,
    );
    if (!context.mounted || _cancelled) return;

    if (existingRoomId != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProjectCaptureScreen(
            projectId: project.id,
            mode: ScanMode.roomByRoom,
            roomId: existingRoomId,
          ),
        ),
      );
      return;
    }

    final roomType = await Navigator.of(context).push<RoomType>(
      MaterialPageRoute<RoomType>(
        builder: (_) => const RoomTypeSelectionScreen(),
      ),
    );
    if (roomType == null || _cancelled || !context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectCaptureScreen(
          projectId: project.id,
          mode: ScanMode.roomByRoom,
          roomType: roomType,
        ),
      ),
    );
  }

  @override
  void cancel() {
    _cancelled = true;
    if (context.mounted) {
      Navigator.of(context).maybePop();
    }
  }
}
