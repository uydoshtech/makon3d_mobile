import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:room_scan_kit/room_scan_kit.dart';

import 'package:makon3d_mobile/base/ios_device.dart';
import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/services/room_usdz_viewer_service.dart';

/// Warm yellow sky gradient aligned with Makon brand colors.
const List<Color> _roomScanSkyGradient = [Color(0xFFFFF6D6), Color(0xFFFFCC00)];

/// Mini preview height — same as UyDosh / web `.roomscan-viewer-wrap`.
const double kScanMiniPreviewHeight = 280;

/// Embedded auto-rotating USDZ preview (iOS SceneKit), with a fullscreen control.
///
/// Prefers [localUsdzPath] when the file still exists; otherwise downloads
/// [usdzUrl] into the per-scan cache. Tap the expand button (or the whole card
/// when [onOpenFullscreen] is set via the overlay) to open the native viewer.
///
/// Reloads persisted furniture edits after fullscreen closes so wall/floor
/// finishes and furniture changes match the full viewer.
class ScanMiniPreview extends StatefulWidget {
  const ScanMiniPreview({
    required this.scanId,
    required this.onOpenFullscreen,
    this.localUsdzPath,
    this.usdzUrl,
    this.isLoadingFullscreen = false,
    super.key,
  });

  /// Cache key for remote downloads (remote scan id or stable hash).
  final int scanId;
  final String? localUsdzPath;
  final String? usdzUrl;
  final bool isLoadingFullscreen;
  final VoidCallback? onOpenFullscreen;

  @override
  State<ScanMiniPreview> createState() => _ScanMiniPreviewState();
}

class _ScanMiniPreviewState extends State<ScanMiniPreview>
    with AutomaticKeepAliveClientMixin {
  String? _localPath;
  Object? _error;
  bool _loading = true;
  double? _downloadProgress;
  int _downloadReceivedBytes = 0;
  int _downloadTotalBytes = 0;
  bool _deferLargePreview = false;
  Map<String, dynamic>? _furnitureEdits;
  String _editsFingerprint = 'none';

  static const int _maximumEmbeddedPreviewBytes = 64 * 1024 * 1024;

  bool get _suspendViewer => widget.isLoadingFullscreen;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ScanMiniPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localUsdzPath != widget.localUsdzPath ||
        oldWidget.usdzUrl != widget.usdzUrl ||
        oldWidget.scanId != widget.scanId) {
      unawaited(_load());
      return;
    }
    // Fullscreen persists edits on dismiss — remount the preview with them.
    if (oldWidget.isLoadingFullscreen && !widget.isLoadingFullscreen) {
      unawaited(_reloadFurnitureEdits());
    }
  }

  String _fingerprintEdits(Map<String, dynamic>? edits) {
    if (edits == null || edits.isEmpty) return 'none';
    try {
      return jsonEncode(edits);
    } catch (_) {
      return edits.hashCode.toString();
    }
  }

  Future<void> _reloadFurnitureEdits() async {
    // Last fullscreen publish is async over the method channel — give it a
    // beat so SharedPreferences / remote PATCH reflect the final document.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final edits = await RoomUsdzViewerService.loadFurnitureEditsForScan(
      widget.scanId,
      remoteScanId: widget.scanId > 0 ? widget.scanId : null,
    );
    if (!mounted) return;
    final fingerprint = _fingerprintEdits(edits);
    if (fingerprint == _editsFingerprint) return;
    setState(() {
      _furnitureEdits = edits;
      _editsFingerprint = fingerprint;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _downloadProgress = null;
      _downloadReceivedBytes = 0;
      _downloadTotalBytes = 0;
      _deferLargePreview = false;
    });

    try {
      if (!isIOSDevice) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'unavailable';
          _localPath = null;
        });
        return;
      }

      final edits = await RoomUsdzViewerService.loadFurnitureEditsForScan(
        widget.scanId,
        remoteScanId: widget.scanId > 0 ? widget.scanId : null,
      );
      final editsFingerprint = _fingerprintEdits(edits);

      final localFile = await RoomUsdzViewerService.resolveLocalUsdz(
        widget.localUsdzPath,
        fallbackPathOrUrl: widget.usdzUrl,
      );
      if (localFile != null) {
        if (!mounted) return;
        setState(() {
          _localPath = localFile.path;
          _furnitureEdits = edits;
          _editsFingerprint = editsFingerprint;
          _deferLargePreview = _isTooLargeForEmbeddedPreview(localFile);
          _loading = false;
          _error = null;
        });
        return;
      }

      final url = widget.usdzUrl?.trim();
      if (url == null || url.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'unavailable';
          _localPath = null;
        });
        return;
      }

      final file = await RoomUsdzViewerService.downloadUsdToCache(
        url,
        scanId: widget.scanId,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          final progress = (received / total).clamp(0.0, 1.0);
          // Avoid rebuilding the native preview for insignificant byte-level
          // updates while still keeping the percentage responsive.
          if (_downloadProgress != null &&
              (progress - _downloadProgress!).abs() < 0.005 &&
              received < total) {
            return;
          }
          setState(() {
            _downloadProgress = progress;
            _downloadReceivedBytes = received;
            _downloadTotalBytes = total;
          });
        },
      );
      if (!mounted) return;
      if (file == null) {
        setState(() {
          _loading = false;
          _error = 'unavailable';
          _localPath = null;
        });
        return;
      }
      setState(() {
        _localPath = file.path;
        _furnitureEdits = edits;
        _editsFingerprint = editsFingerprint;
        _deferLargePreview = _isTooLargeForEmbeddedPreview(file);
        _loading = false;
        _error = null;
      });
      debugPrint(
        'ScanMiniPreview ready scan=${widget.scanId} '
        'bytes=${file.lengthSync()} deferred=$_deferLargePreview '
        'edits=$_editsFingerprint source=${widget.usdzUrl}',
      );
    } catch (e) {
      debugPrint(
        'ScanMiniPreview failed scan=${widget.scanId} '
        'source=${widget.usdzUrl}: $e',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
        _localPath = null;
      });
    }
  }

  bool _isTooLargeForEmbeddedPreview(File file) {
    try {
      return file.lengthSync() > _maximumEmbeddedPreviewBytes;
    } catch (_) {
      return true;
    }
  }

  void _onFullscreenTap() {
    if (_suspendViewer || widget.onOpenFullscreen == null) return;
    widget.onOpenFullscreen!();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final path = _localPath;
    final showPreview = path != null && _error == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _roomScanSkyGradient,
          ),
        ),
        child: SizedBox(
          height: kScanMiniPreviewHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A photogrammetry USDZ may decode several GB of texture data.
              // Unmount the embedded SceneKit view before fullscreen creates
              // its own scene, otherwise iOS briefly holds both copies.
              if (showPreview && !_deferLargePreview && !_suspendViewer)
                RoomUsdzPreview(
                  // Remount when edits change — PlatformView creationParams
                  // are only read once at create time.
                  key: ValueKey(
                    'makonPreview-${widget.scanId}-$path-$_editsFingerprint',
                  ),
                  filePath: path,
                  autoRotate: !_suspendViewer,
                  // Fill the project card more aggressively than the shared
                  // listing preview while retaining a small rotation margin.
                  framingPadding: 1.14,
                  furnitureEdits: _furnitureEdits,
                ),
              if (showPreview && _deferLargePreview && !_suspendViewer)
                Center(
                  child: InkWell(
                    onTap: _onFullscreenTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.view_in_ar_outlined,
                            color: Colors.black54,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            L10n.get('room_3d_viewer_title'),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_loading && !showPreview)
                ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                    child: _downloadProgress == null
                        ? const CircularProgressIndicator.adaptive()
                        : _DownloadProgressIndicator(
                            progress: _downloadProgress!,
                            receivedBytes: _downloadReceivedBytes,
                            totalBytes: _downloadTotalBytes,
                          ),
                  ),
                ),
              if (!_suspendViewer && _error != null)
                ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          L10n.get('room_3d_load_error_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => unawaited(_load()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                          child: Text(L10n.get('scans_retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                right: 6,
                bottom: 6,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _suspendViewer ? null : _onFullscreenTap,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: _suspendViewer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadProgressIndicator extends StatelessWidget {
  const _DownloadProgressIndicator({
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final double progress;
  final int receivedBytes;
  final int totalBytes;

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final percentValue = progress * 100;
    final percent = percentValue > 0 && percentValue < 1
        ? percentValue.toStringAsFixed(2)
        : percentValue.toStringAsFixed(0);
    return SizedBox(
      width: 210,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$percent%',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: Colors.black12,
            color: Colors.black54,
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
