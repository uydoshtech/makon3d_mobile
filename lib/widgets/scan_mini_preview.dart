import 'dart:async';
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
  final GlobalKey _previewViewKey = GlobalKey(
    debugLabel: 'makonScanMiniPreview',
  );

  String? _localPath;
  Object? _error;
  bool _loading = true;
  bool _suspendForFullscreen = false;

  bool get _suspendViewer =>
      _suspendForFullscreen || widget.isLoadingFullscreen;

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
    }
    if (oldWidget.isLoadingFullscreen && !widget.isLoadingFullscreen) {
      _suspendForFullscreen = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
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

      final local = widget.localUsdzPath?.trim();
      if (local != null && local.isNotEmpty) {
        final file = File(local);
        if (file.existsSync() && file.lengthSync() > 0) {
          if (!mounted) return;
          setState(() {
            _localPath = file.path;
            _loading = false;
            _error = null;
          });
          return;
        }
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
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
        _localPath = null;
      });
    }
  }

  void _onFullscreenTap() {
    if (_suspendViewer || widget.onOpenFullscreen == null) return;
    setState(() => _suspendForFullscreen = true);
    widget.onOpenFullscreen!();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final path = _localPath;
    final showPreview = !_suspendViewer && path != null && _error == null;

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
              if (showPreview)
                RoomUsdzPreview(
                  key: _previewViewKey,
                  filePath: path,
                  autoRotate: true,
                ),
              if (_suspendViewer || _loading)
                const ColoredBox(
                  color: Colors.transparent,
                  child: Center(child: CircularProgressIndicator.adaptive()),
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
