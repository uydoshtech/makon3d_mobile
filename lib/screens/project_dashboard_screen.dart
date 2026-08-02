import 'dart:async';

import 'package:flutter/material.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/models/project_room.dart';
import 'package:makon3d_mobile/models/room_type.dart';
import 'package:makon3d_mobile/scan_flow/makon_entire_housing_coordinator.dart';
import 'package:makon3d_mobile/scan_flow/makon_room_by_room_coordinator.dart';
import 'package:makon3d_mobile/screens/edit_project_screen.dart';
import 'package:makon3d_mobile/screens/room_materials_screen.dart';
import 'package:makon3d_mobile/screens/scan_detail_screen.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';
import 'package:makon3d_mobile/widgets/photogrammetry_package_actions.dart';
import 'package:makon3d_mobile/widgets/project_delete_dialog.dart';
import 'package:makon3d_mobile/widgets/scan_mini_preview.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Mode-aware project home. Does not re-ask for scan mode.
class ProjectDashboardScreen extends StatefulWidget {
  const ProjectDashboardScreen({required this.projectId, super.key});

  final String projectId;

  @override
  State<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends State<ProjectDashboardScreen> {
  bool _openingFullscreen = false;
  List<String> _remoteRoomTypes = const <String>[];
  Map<String, int> _remoteObjectCounts = const <String, int>{};
  int? _loadedDetectionScanId;

  @override
  void initState() {
    super.initState();
    MakonProjectStore.instance.addListener(_onStoreChanged);
    unawaited(
      MakonProjectStore.instance.ensureLoaded().then((_) async {
        await _refreshProjectScanMedia();
        await _loadDetectionMetadata();
      }),
    );
  }

  /// Pull latest remote USDZ/GLB URLs so photogrammetry replacements show up
  /// without re-scanning. Persists when the URL (or cleared local path) changes.
  Future<void> _refreshProjectScanMedia() async {
    final project = _project;
    if (project == null) return;
    final scans = <HousingScan>[
      if (project.entireHousingScan != null) project.entireHousingScan!,
      for (final room in project.rooms)
        if (room.scan != null) room.scan!,
    ];
    for (final scan in scans) {
      if (scan.remoteScanId == null) continue;
      try {
        final updated = await MakonProjectStore.instance.refreshScanMedia(scan);
        await MakonProjectStore.instance.replaceScanMedia(
          previous: scan,
          updated: updated,
        );
      } catch (_) {
        // Offline / transient API errors — keep the cached project media.
      }
    }
  }

  @override
  void dispose() {
    MakonProjectStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
      unawaited(_loadDetectionMetadata());
    }
  }

  Future<void> _loadDetectionMetadata() async {
    final scan = _project?.entireHousingScan;
    final remoteId = scan?.remoteScanId;
    if (scan == null || remoteId == null) return;
    if (scan.roomTypes.isNotEmpty && scan.objectCounts.isNotEmpty) return;
    if (_loadedDetectionScanId == remoteId) return;
    _loadedDetectionScanId = remoteId;
    try {
      final remote = await ScanUploadService.getScan(remoteId);
      if (!mounted || _project?.entireHousingScan?.remoteScanId != remoteId) {
        return;
      }
      setState(() {
        _remoteRoomTypes = remote.roomTypes;
        _remoteObjectCounts = remote.objectCounts;
      });
    } catch (_) {
      // Detection metadata is decorative; project details remain usable.
    }
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
    await _openScan(scan);
  }

  Future<void> _openScan(HousingScan scan) async {
    if (_openingFullscreen) return;
    setState(() => _openingFullscreen = true);
    try {
      final ok = await RoomUsdzViewerService.openUsdz(
        localUsdzPath: scan.localUsdzPath,
        usdzUrl: scan.usdzUrl,
        scanId: scan.remoteScanId ?? scan.id.hashCode,
        languageCode: LanguageState().currentLanguage,
        worldPlusXBearingDeg: scan.worldPlusXBearingDeg,
        shareScanId: scan.remoteScanId,
      );
      if (!ok && mounted) {
        Toasts.showError(context, L10n.get('scans_open_error'));
      }
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get('scans_open_error'));
    } finally {
      if (mounted) setState(() => _openingFullscreen = false);
    }
  }

  Future<void> _deleteProject(MakonProject project) async {
    final deleted = await confirmAndDeleteProject(context, project);
    if (deleted && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDeleteRoom(ProjectRoom room) async {
    final title = room.name?.isNotEmpty == true
        ? room.name!
        : L10n.get(room.roomType.titleKey);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(L10n.get('project_room_delete_confirm_title')),
          content: Text(
            L10n.get(
              'project_room_delete_confirm_message',
            ).replaceAll('{name}', title),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(L10n.get('project_delete_cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(L10n.get('project_delete_confirm')),
            ),
          ],
        );
      },
    );
    return confirmed == true && mounted;
  }

  Future<void> _deleteRoom(ProjectRoom room) async {
    await MakonProjectStore.instance.deleteRoom(
      projectId: widget.projectId,
      roomId: room.id,
    );
    if (mounted) {
      Toasts.showSuccess(context, L10n.get('project_room_deleted'));
    }
  }

  Future<void> _editProject(MakonProject project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditProjectScreen(project: project),
      ),
    );
  }

  Future<void> _openRoomDetail(ProjectRoom room) async {
    final scan = room.scan;
    if (scan == null) return;
    final title = room.name?.isNotEmpty == true
        ? room.name!
        : L10n.get(room.roomType.titleKey);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanDetailScreen(
          title: title,
          titleIcon: room.roomType.icon,
          scan: scan,
          projectId: widget.projectId,
          roomId: room.id,
          onRescan: () {
            Navigator.of(context).pop();
            unawaited(_rescanRoom(room));
          },
        ),
      ),
    );
  }

  Future<void> _openEntireHousingMaterials() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoomMaterialsScreen(projectId: widget.projectId),
      ),
    );
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
        actions: [
          IconButton(
            tooltip: L10n.get('project_edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => unawaited(_editProject(project)),
          ),
          IconButton(
            tooltip: L10n.get('project_delete'),
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => unawaited(_deleteProject(project)),
          ),
        ],
      ),
      body: project.scanMode == ScanMode.entireHousing
          ? _EntireHousingBody(
              project: project,
              openingFullscreen: _openingFullscreen,
              onStartScan: _startEntireHousingScan,
              onOpenModel: () => unawaited(_openHousingModel()),
              onOpenMaterials: () => unawaited(_openEntireHousingMaterials()),
              detectedRoomTypes:
                  project.entireHousingScan?.roomTypes.isNotEmpty == true
                  ? project.entireHousingScan!.roomTypes
                  : _remoteRoomTypes,
              detectedObjectCounts:
                  project.entireHousingScan?.objectCounts.isNotEmpty == true
                  ? project.entireHousingScan!.objectCounts
                  : _remoteObjectCounts,
            )
          : _RoomByRoomBody(
              project: project,
              onAddRoom: _addRoom,
              onOpenRoom: (room) => unawaited(_openRoomDetail(room)),
              onRescanRoom: _rescanRoom,
              onConfirmDeleteRoom: _confirmDeleteRoom,
              onDeleteRoom: _deleteRoom,
            ),
    );
  }
}

class _EntireHousingBody extends StatelessWidget {
  const _EntireHousingBody({
    required this.project,
    required this.openingFullscreen,
    required this.onStartScan,
    required this.onOpenModel,
    required this.onOpenMaterials,
    required this.detectedRoomTypes,
    required this.detectedObjectCounts,
  });

  final MakonProject project;
  final bool openingFullscreen;
  final VoidCallback onStartScan;
  final VoidCallback onOpenModel;
  final VoidCallback onOpenMaterials;
  final List<String> detectedRoomTypes;
  final Map<String, int> detectedObjectCounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasModel = project.hasEntireHousingModel;
    final scan = project.entireHousingScan;

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
        if (hasModel && scan != null) ...[
          ScanMiniPreview(
            scanId: scan.remoteScanId ?? scan.id.hashCode,
            localUsdzPath: scan.localUsdzPath,
            usdzUrl: scan.usdzUrl,
            isLoadingFullscreen: openingFullscreen,
            onOpenFullscreen: onOpenModel,
          ),
          if (detectedRoomTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetectedRoomTypesPill(roomTypes: detectedRoomTypes),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.straighten),
            title: Text(L10n.get('project_action_measurements')),
            subtitle: Text(
              project.entireHousingScan?.floorAreaM2 != null
                  ? L10n.get('room_3d_dimensions_line2_template').replaceAll(
                      '{floorArea}',
                      project.entireHousingScan!.floorAreaM2!.toStringAsFixed(
                        1,
                      ),
                    )
                  : L10n.get('scans_no_metrics'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.grid_view_rounded),
            title: Text(L10n.get('project_action_materials')),
            subtitle: Text(L10n.get('materials_surfaces_summary')),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenMaterials,
          ),
          if (detectedObjectCounts.isNotEmpty)
            _DetectedObjectsSection(counts: detectedObjectCounts),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onStartScan,
            icon: const Icon(Icons.refresh),
            label: Text(L10n.get('project_rescan')),
          ),
          if (scan.remoteScanId != null) ...[
            const SizedBox(height: 12),
            PhotogrammetryPackageActions(scan: scan),
          ],
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

class _DetectedRoomTypesPill extends StatelessWidget {
  const _DetectedRoomTypesPill({required this.roomTypes});

  final List<String> roomTypes;

  @override
  Widget build(BuildContext context) {
    final supported = <RoomType>{};
    for (final value in roomTypes) {
      final type = RoomType.tryParse(value);
      if (type == RoomType.livingRoom ||
          type == RoomType.bedroom ||
          type == RoomType.kitchen ||
          type == RoomType.bathroom) {
        supported.add(type!);
      }
    }
    if (supported.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.primary.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < supported.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Tooltip(
                message: L10n.get(supported.elementAt(index).titleKey),
                child: Icon(
                  supported.elementAt(index).icon,
                  size: 19,
                  color: colors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetectedObjectsSection extends StatelessWidget {
  const _DetectedObjectsSection({required this.counts});

  final Map<String, int> counts;

  static const _labelKeys = <String, String>{
    'window': 'room_scan_stats_windows',
    'door': 'room_scan_stats_doors',
    'opening': 'room_scan_stats_openings',
    'storage': 'room_scan_stats_storage',
    'cabinet': 'room_scan_stats_cabinet',
    'bed': 'room_scan_stats_bed',
    'sofa': 'room_scan_stats_sofa',
    'table': 'room_scan_stats_table',
    'chair': 'room_scan_stats_chair',
    'television': 'room_scan_stats_television',
    'refrigerator': 'room_scan_stats_refrigerator',
    'sink': 'room_scan_stats_sink',
    'toilet': 'room_scan_stats_toilet',
    'bathtub': 'room_scan_stats_bathtub',
    'shower': 'room_scan_stats_shower',
    'oven': 'room_scan_stats_oven',
    'stove': 'room_scan_stats_stove',
    'dishwasher': 'room_scan_stats_dishwasher',
    'washerDryer': 'room_scan_stats_washer_dryer',
    'fireplace': 'room_scan_stats_fireplace',
    'stairs': 'room_scan_stats_stairs',
  };

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((entry) => entry.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 56, right: 8, bottom: 8),
      leading: const Icon(Icons.chair_outlined),
      title: Text(L10n.get('project_detected_objects')),
      shape: const Border(),
      collapsedShape: const Border(),
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    L10n.get(_labelKeys[entry.key] ?? 'room_scan_stats_object'),
                  ),
                ),
                Text(
                  '× ${entry.value}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
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
    required this.onConfirmDeleteRoom,
    required this.onDeleteRoom,
  });

  final MakonProject project;
  final VoidCallback onAddRoom;
  final ValueChanged<ProjectRoom> onOpenRoom;
  final ValueChanged<ProjectRoom> onRescanRoom;
  final Future<bool> Function(ProjectRoom room) onConfirmDeleteRoom;
  final ValueChanged<ProjectRoom> onDeleteRoom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rooms = project.rooms;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                _DashboardInfoCard(
                  icon: Icons.view_in_ar,
                  label: L10n.get('project_scan_mode_label'),
                  title: L10n.get(ScanMode.roomByRoom.titleKey),
                  description: L10n.get(ScanMode.roomByRoom.subtitleKey),
                ),
                const SizedBox(height: 28),
                Text(
                  L10n.get('project_rooms_heading'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (rooms.isEmpty)
                  _EmptyRoomsCard(message: L10n.get('project_rooms_empty'))
                else
                  ...rooms.map((room) {
                    final title = room.name?.isNotEmpty == true
                        ? room.name!
                        : L10n.get(room.roomType.titleKey);
                    return Dismissible(
                      key: ValueKey(room.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => onConfirmDeleteRoom(room),
                      onDismissed: (_) => onDeleteRoom(room),
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: theme.colorScheme.error,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onError,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          room.roomType.icon,
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
                      ),
                    );
                  }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: FilledButton.icon(
              onPressed: onAddRoom,
              icon: const Icon(Icons.add),
              label: Text(L10n.get('project_add_room')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardInfoCard extends StatelessWidget {
  const _DashboardInfoCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoomsCard extends StatelessWidget {
  const _EmptyRoomsCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.meeting_room_outlined, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
