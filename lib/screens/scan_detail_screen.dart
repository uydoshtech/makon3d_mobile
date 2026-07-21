import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/screens/room_floor_materials_screen.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';
import 'package:makon3d_mobile/widgets/scan_mini_preview.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Project / room scan details with an embedded mini 3D preview (UyDosh-style).
class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({
    required this.title,
    required this.scan,
    this.projectId,
    this.roomId,
    this.onRescan,
    super.key,
  });

  final String title;
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

  int get _cacheScanId =>
      widget.scan.remoteScanId ?? widget.scan.id.hashCode;

  Future<void> _openFullscreen() async {
    if (_openingFullscreen) return;
    setState(() => _openingFullscreen = true);
    try {
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
    final hasDims = scan.floorLongM != null &&
        scan.floorShortM != null &&
        scan.heightM != null &&
        scan.floorAreaM2 != null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_in_ar),
            title: Text(L10n.get('project_action_3d_model')),
            trailing: const Icon(Icons.fullscreen),
            onTap: () => unawaited(_openFullscreen()),
          ),
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
                  L10n.get('room_3d_dimensions_height_template').replaceAll(
                    '{height}',
                    scan.heightM!.toStringAsFixed(1),
                  ),
                  L10n.get('room_3d_dimensions_line2_template').replaceAll(
                    '{floorArea}',
                    scan.floorAreaM2!.toStringAsFixed(1),
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
          if (widget.projectId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.grid_view_rounded),
              title: Text(L10n.get('room_action_materials')),
              subtitle: Text(L10n.get('materials_floor_surface')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => RoomFloorMaterialsScreen(
                      projectId: widget.projectId!,
                      roomId: widget.roomId,
                    ),
                  ),
                );
              },
            ),
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
