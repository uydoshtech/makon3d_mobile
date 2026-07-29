import 'dart:async';

import 'package:flutter/material.dart';
import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/housing_scan.dart';
import 'package:makon3d_mobile/services/scan_share_service.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';
import 'package:room_scan_kit/photogrammetry_upload.dart';

/// Share / retry controls for a local photogrammetry ZIP bound to a Makon scan.
///
/// Visible share action only when an on-device archive exists for this scan
/// (or a recent orphan package if target association failed).
class PhotogrammetryPackageActions extends StatefulWidget {
  const PhotogrammetryPackageActions({required this.scan, super.key});

  final HousingScan scan;

  @override
  State<PhotogrammetryPackageActions> createState() =>
      _PhotogrammetryPackageActionsState();
}

class _PhotogrammetryPackageActionsState
    extends State<PhotogrammetryPackageActions> {
  bool _retrying = false;
  bool _sharing = false;
  String? _localPackagePath;

  int? get _remoteId => widget.scan.remoteScanId;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshLocalPackage());
  }

  @override
  void didUpdateWidget(covariant PhotogrammetryPackageActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scan.id != widget.scan.id ||
        oldWidget.scan.remoteScanId != widget.scan.remoteScanId) {
      unawaited(_refreshLocalPackage());
    }
  }

  Future<void> _refreshLocalPackage() async {
    final remoteId = _remoteId;
    if (remoteId == null) {
      if (mounted) setState(() => _localPackagePath = null);
      return;
    }
    final store = PhotogrammetryLocalPackageStore.instance;
    final stored = await store.findByTarget(
      targetType: 'makon3d_scan',
      targetId: remoteId,
    );
    if (stored != null && stored.fileExists) {
      if (mounted) setState(() => _localPackagePath = stored.packagePath);
      return;
    }
    // Fallback: orphan zip from the latest capture (association may have failed).
    final latest = await store.latestPath();
    if (!mounted) return;
    setState(() => _localPackagePath = latest);
  }

  Future<void> _sharePackage() async {
    final path = _localPackagePath;
    if (path == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await ScanShareService.sharePhotogrammetryPackage(
        path,
        scanId: _remoteId,
      );
    } catch (error) {
      debugPrint('Photogrammetry share failed: $error');
      if (!mounted) return;
      Toasts.showError(
        context,
        L10n.get('room_scan_photogrammetry_share_failed'),
      );
      await _refreshLocalPackage();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _retryPhotogrammetry() async {
    final remoteId = _remoteId;
    if (remoteId == null || _retrying) return;
    setState(() => _retrying = true);
    try {
      await PhotogrammetryUpload.instance.retryLocal(
        apiBaseUrl: ScanUploadService.basePath,
        targetType: 'makon3d_scan',
        targetId: remoteId,
        onProgress: (_) {},
      );
      if (!mounted) return;
      Toasts.showSuccess(context, L10n.get('room_scan_photogrammetry_retry_ok'));
      await _refreshLocalPackage();
    } on StateError {
      if (!mounted) return;
      Toasts.showError(
        context,
        L10n.get('room_scan_photogrammetry_retry_missing'),
      );
    } catch (error) {
      debugPrint('Photogrammetry retry failed: $error');
      if (!mounted) return;
      Toasts.showError(
        context,
        L10n.get('room_scan_photogrammetry_retry_failed'),
      );
      await _refreshLocalPackage();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remoteId == null) return const SizedBox.shrink();

    final hasLocal = _localPackagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLocal) ...[
          OutlinedButton.icon(
            onPressed: _sharing ? null : () => unawaited(_sharePackage()),
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(L10n.get('room_scan_photogrammetry_share')),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _retrying ? null : () => unawaited(_retryPhotogrammetry()),
          icon: _retrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(L10n.get('room_scan_photogrammetry_retry')),
        ),
        if (!hasLocal)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              L10n.get('room_scan_photogrammetry_retry_missing'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
