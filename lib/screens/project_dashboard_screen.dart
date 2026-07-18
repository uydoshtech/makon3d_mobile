import 'dart:async';

import 'package:flutter/material.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/scan_flow/makon_entire_housing_coordinator.dart';
import 'package:makon3d_mobile/scan_flow/makon_room_by_room_coordinator.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Mode-aware project home. Does not re-ask for scan mode.
class ProjectDashboardScreen extends StatefulWidget {
  const ProjectDashboardScreen({required this.projectId, super.key});

  final String projectId;

  @override
  State<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends State<ProjectDashboardScreen> {
  @override
  void initState() {
    super.initState();
    MakonProjectStore.instance.addListener(_onStoreChanged);
    unawaited(MakonProjectStore.instance.ensureLoaded());
  }

  @override
  void dispose() {
    MakonProjectStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  MakonProject? get _project =>
      MakonProjectStore.instance.getById(widget.projectId);

  Future<void> _startEntireHousingScan() async {
    final project = _project;
    if (project == null) return;
    await MakonEntireHousingCoordinator(
      context: context,
      project: project,
    ).start();
  }

  Future<void> _addRoom() async {
    final project = _project;
    if (project == null) return;
    await MakonRoomByRoomCoordinator(
      context: context,
      project: project,
    ).start();
  }

  Future<void> _rescanRoom(ProjectRoom room) async {
    final project = _project;
    if (project == null) return;
    await MakonRoomByRoomCoordinator(
      context: context,
      project: project,
      existingRoomId: room.id,
    ).start();
  }

  Future<void> _openHousingModel() async {
    final scan = _project?.entireHousingScan;
    if (scan == null) return;
    await _openScan(
      scan.localUsdzPath,
      scan.usdzUrl,
      scan.worldPlusXBearingDeg,
      remoteScanId: scan.remoteScanId,
    );
  }

  Future<void> _openRoomModel(ProjectRoom room) async {
    final scan = room.scan;
    if (scan == null) return;
    await _openScan(
      scan.localUsdzPath,
      scan.usdzUrl,
      scan.worldPlusXBearingDeg,
      remoteScanId: scan.remoteScanId,
    );
  }

  Future<void> _openScan(
    String? localPath,
    String? usdzUrl,
    double? bearing, {
    int? remoteScanId,
  }) async {
    try {
      if (localPath != null && localPath.isNotEmpty) {
        await RoomUsdzViewerService.presentLocalFile(
          localPath,
          languageCode: LanguageState().currentLanguage,
          worldPlusXBearingDeg: bearing,
        );
        return;
      }
      if (usdzUrl != null && usdzUrl.isNotEmpty) {
        await RoomUsdzViewerService.downloadAndPresent(
          usdzUrl,
          scanId: remoteScanId ?? usdzUrl.hashCode,
          languageCode: LanguageState().currentLanguage,
          worldPlusXBearingDeg: bearing,
        );
        return;
      }
      if (!mounted) return;
      Toasts.showError(context, L10n.get('scans_open_error'));
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('scans_open_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(L10n.get('project_not_found'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
      ),
      body: project.scanMode == ScanMode.entireHousing
          ? _EntireHousingBody(
              project: project,
              onStartScan: _startEntireHousingScan,
              onOpenModel: _openHousingModel,
            )
          : _RoomByRoomBody(
              project: project,
              onAddRoom: _addRoom,
              onOpenRoom: _openRoomModel,
              onRescanRoom: _rescanRoom,
            ),
    );
  }
}

class _EntireHousingBody extends StatelessWidget {
  const _EntireHousingBody({
    required this.project,
    required this.onStartScan,
    required this.onOpenModel,
  });

  final MakonProject project;
  final VoidCallback onStartScan;
  final VoidCallback onOpenModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasModel = project.hasEntireHousingModel;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          L10n.get('project_scan_mode_label'),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          L10n.get(ScanMode.entireHousing.titleKey),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        if (hasModel) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_in_ar),
            title: Text(L10n.get('project_action_3d_model')),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenModel,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.straighten),
            title: Text(L10n.get('project_action_measurements')),
            subtitle: Text(
              project.entireHousingScan?.floorAreaM2 != null
                  ? L10n.get('room_3d_dimensions_line2_template').replaceAll(
                      '{floorArea}',
                      project.entireHousingScan!.floorAreaM2!
                          .toStringAsFixed(1),
                    )
                  : L10n.get('scans_no_metrics'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.construction_outlined),
            title: Text(L10n.get('project_action_materials')),
            subtitle: Text(L10n.get('project_materials_coming_soon')),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onStartScan,
            icon: const Icon(Icons.refresh),
            label: Text(L10n.get('project_rescan')),
          ),
        ] else ...[
          Text(
            L10n.get(ScanMode.entireHousing.subtitleKey),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onStartScan,
            icon: const Icon(Icons.view_in_ar),
            label: Text(L10n.get('room_scan_start')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoomByRoomBody extends StatelessWidget {
  const _RoomByRoomBody({
    required this.project,
    required this.onAddRoom,
    required this.onOpenRoom,
    required this.onRescanRoom,
  });

  final MakonProject project;
  final VoidCallback onAddRoom;
  final ValueChanged<ProjectRoom> onOpenRoom;
  final ValueChanged<ProjectRoom> onRescanRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rooms = project.rooms;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          L10n.get('project_scan_mode_label'),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          L10n.get(ScanMode.roomByRoom.titleKey),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          L10n.get('project_rooms_heading'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(L10n.get('project_rooms_empty')),
          )
        else
          ...rooms.map((room) {
            final title = room.name?.isNotEmpty == true
                ? room.name!
                : L10n.get(room.roomType.titleKey);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                room.isScanned
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: room.isScanned
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: Text(title),
              subtitle: Text(
                room.isScanned
                    ? L10n.get('project_room_scanned')
                    : L10n.get('project_room_pending'),
              ),
              trailing: room.isScanned
                  ? IconButton(
                      icon: const Icon(Icons.view_in_ar),
                      onPressed: () => onOpenRoom(room),
                    )
                  : TextButton(
                      onPressed: () => onRescanRoom(room),
                      child: Text(L10n.get('room_scan_start')),
                    ),
              onTap: room.isScanned
                  ? () => onOpenRoom(room)
                  : () => onRescanRoom(room),
            );
          }),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAddRoom,
          icon: const Icon(Icons.add),
          label: Text(L10n.get('project_add_room')),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Toasts.showInfo(
              context,
              L10n.get('project_combined_view_coming_soon'),
            );
          },
          icon: const Icon(Icons.apartment_outlined),
          label: Text(L10n.get('project_generate_combined')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Toasts.showInfo(
              context,
              L10n.get('project_materials_coming_soon'),
            );
          },
          icon: const Icon(Icons.construction_outlined),
          label: Text(L10n.get('project_action_materials')),
        ),
      ],
    );
  }
}
