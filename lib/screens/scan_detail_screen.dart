import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';
import 'package:makon3d_mobile/widgets/scan_mini_preview.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Project / room scan details with an embedded mini 3D preview (UyDosh-style).
class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({
    required this.title,
    required this.scan,
    this.onRescan,
    super.key,
  });

  final String title;
  final HousingScan scan;
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
      final local = widget.scan.localUsdzPath;
      if (local != null && local.isNotEmpty) {
        await RoomUsdzViewerService.presentLocalFile(
          local,
          languageCode: LanguageState().currentLanguage,
          worldPlusXBearingDeg: widget.scan.worldPlusXBearingDeg,
        );
        return;
      }
      final url = widget.scan.usdzUrl;
      if (url != null && url.isNotEmpty) {
        await RoomUsdzViewerService.downloadAndPresent(
          url,
          scanId: _cacheScanId,
          languageCode: LanguageState().currentLanguage,
          worldPlusXBearingDeg: widget.scan.worldPlusXBearingDeg,
        );
        return;
      }
      if (!mounted) return;
      Toasts.showError(context, L10n.get('scans_open_error'));
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
