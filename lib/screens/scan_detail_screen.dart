import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/screens/room_materials_screen.dart';
import 'package:makon3d_mobile/screens/textured_glb_viewer_screen.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';
import 'package:makon3d_mobile/widgets/scan_mini_preview.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Project / room scan details with an embedded mini 3D preview (UyDosh-style).
class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({
    required this.title,
    required this.scan,
    this.titleIcon,
    this.projectId,
    this.roomId,
    this.onRescan,
    super.key,
  });

  final String title;

  /// Room-type icon shown before the title (matches the add-room picker).
  final IconData? titleIcon;

  final HousingScan scan;

  /// When set with [roomId] (or alone for entire housing), enables materials.
  final String? projectId;
  final String? roomId;
  final VoidCallback? onRescan;

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  bool _openingFullscreen = false;

  int get _cacheScanId => widget.scan.remoteScanId ?? widget.scan.id.hashCode;

  Future<void> _openFullscreen() async {
    if (_openingFullscreen) return;
    setState(() => _openingFullscreen = true);
    try {
      final remoteId = widget.scan.remoteScanId;
      if (remoteId != null) {
        final refreshed = await ScanUploadService.getScan(remoteId);
        if (!mounted) return;
        final textured = refreshed.texturedGlbUrl;
        if (textured != null && textured.isNotEmpty) {
          final choice = await showModalBottomSheet<String>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text(L10n.get('room_3d_structure')),
                    onTap: () => Navigator.pop(context, 'structure'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.texture),
                    title: Text(L10n.get('room_3d_textured')),
                    onTap: () => Navigator.pop(context, 'textured'),
                  ),
                ],
              ),
            ),
          );
          if (!mounted || choice == null) return;
          if (choice == 'textured') {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => TexturedGlbViewerScreen(glbUrl: textured),
              ),
            );
            return;
          }
        }
      }
      final ok = await RoomUsdzViewerService.openUsdz(
        localUsdzPath: widget.scan.localUsdzPath,
        usdzUrl: widget.scan.usdzUrl,
        scanId: _cacheScanId,
        languageCode: LanguageState().currentLanguage,
        worldPlusXBearingDeg: widget.scan.worldPlusXBearingDeg,
        shareScanId: widget.scan.remoteScanId,
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

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final hasDims =
        scan.floorLongM != null &&
        scan.floorShortM != null &&
        scan.heightM != null &&
        scan.floorAreaM2 != null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.titleIcon != null) ...[
              Icon(widget.titleIcon),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(widget.title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          ScanMiniPreview(
            scanId: _cacheScanId,
            localUsdzPath: scan.localUsdzPath,
            usdzUrl: scan.usdzUrl,
            isLoadingFullscreen: _openingFullscreen,
            onOpenFullscreen: () => unawaited(_openFullscreen()),
          ),
          const SizedBox(height: 16),
          if (hasDims)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten),
              title: Text(L10n.get('project_action_measurements')),
              subtitle: Text(
                [
                  L10n.get('room_3d_dimensions_line1_template')
                      .replaceAll(
                        '{floorLong}',
                        scan.floorLongM!.toStringAsFixed(1),
                      )
                      .replaceAll(
                        '{floorShort}',
                        scan.floorShortM!.toStringAsFixed(1),
                      ),
                  L10n.get(
                    'room_3d_dimensions_height_template',
                  ).replaceAll('{height}', scan.heightM!.toStringAsFixed(1)),
                  L10n.get('room_3d_dimensions_line2_template').replaceAll(
                    '{floorArea}',
                    scan.floorAreaM2!.toStringAsFixed(1),
                  ),
                  // Approximate footprint perimeter from the OBB dims.
                  L10n.get('room_scan_results_perimeter').replaceAll(
                    '{value}',
                    (2 * (scan.floorLongM! + scan.floorShortM!))
                        .toStringAsFixed(1),
                  ),
                ].join('\n'),
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.straighten),
              title: Text(L10n.get('project_action_measurements')),
              subtitle: Text(L10n.get('scans_no_metrics')),
            ),
          if (widget.projectId != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.grid_view_rounded),
              title: Text(L10n.get('materials_floor_surface')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => RoomMaterialsScreen(
                      projectId: widget.projectId!,
                      roomId: widget.roomId,
                      showSurfaceSelector: false,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.format_paint_outlined),
              title: Text(L10n.get('materials_walls_surface')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => RoomMaterialsScreen(
                      projectId: widget.projectId!,
                      roomId: widget.roomId,
                      initialSurface: MaterialsSurface.walls,
                      showSurfaceSelector: false,
                    ),
                  ),
                );
              },
            ),
          ],
          if (widget.onRescan != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onRescan,
              icon: const Icon(Icons.refresh),
              label: Text(L10n.get('project_rescan')),
            ),
          ],
        ],
      ),
    );
  }
}
