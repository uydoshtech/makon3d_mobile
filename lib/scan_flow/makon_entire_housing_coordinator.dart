import 'package:flutter/material.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/screens/project_capture_screen.dart';
import 'package:makon3d_mobile/services/makon_analytics.dart';

/// Orchestrates Makon entire-housing capture for one project.
class MakonEntireHousingCoordinator implements ScanFlowCoordinator {
  MakonEntireHousingCoordinator({
    required this.context,
    required this.project,
    this.entryPoint = 'project_dashboard',
  });

  final BuildContext context;
  final MakonProject project;
  final String entryPoint;

  bool _cancelled = false;

  @override
  Future<void> start() async {
    _cancelled = false;
    MakonAnalytics.entireHousingScanStarted(
      projectId: project.id,
      entryPoint: entryPoint,
    );
    if (!context.mounted || _cancelled) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectCaptureScreen(
          projectId: project.id,
          mode: ScanMode.entireHousing,
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
