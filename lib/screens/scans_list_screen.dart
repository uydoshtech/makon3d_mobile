import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/models/makon_scan.dart";
import "package:makon3d_mobile/services/room_usdz_viewer_service.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";
import "package:makon3d_mobile/services/scans_refresh_notifier.dart";
import "package:makon3d_mobile/widgets/toasts.dart";

/// Lists anonymous scans uploaded from this install (`device_id`).
class ScansListScreen extends StatefulWidget {
  const ScansListScreen({super.key, this.isActive = false});

  /// When true (Scans tab selected), loads / refreshes the list.
  final bool isActive;

  @override
  State<ScansListScreen> createState() => _ScansListScreenState();
}

class _ScansListScreenState extends State<ScansListScreen> {
  List<MakonScan>? _scans;
  Object? _error;
  bool _loading = false;
  int? _openingId;
  CancelToken? _loadToken;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    ScansRefreshNotifier.instance.addListener(_onRefresh);
    if (widget.isActive) {
      _loadedOnce = true;
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant ScansListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadedOnce = true;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    ScansRefreshNotifier.instance.removeListener(_onRefresh);
    _loadToken?.cancel("disposed");
    super.dispose();
  }

  void _onRefresh() {
    if (!widget.isActive && !_loadedOnce) return;
    unawaited(_load());
  }

  Future<void> _load() async {
    _loadToken?.cancel("reload");
    final token = CancelToken();
    _loadToken = token;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scans = await ScanUploadService.listScansForThisDevice(
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _scans = scans;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted || CancelToken.isCancel(e) || token.isCancelled) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token.isCancelled) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openScan(MakonScan scan) async {
    final url = scan.usdzUrl;
    if (url == null || url.isEmpty) {
      Toasts.showError(context, L10n.get("scans_open_error"));
      return;
    }
    setState(() => _openingId = scan.id);
    try {
      await RoomUsdzViewerService.downloadAndPresent(
        url,
        scanId: scan.id,
        languageCode: LanguageState().currentLanguage,
        worldPlusXBearingDeg: scan.worldPlusXBearingDeg,
        shareScanId: scan.id,
      );
    } catch (_) {
      if (!mounted) return;
      Toasts.showError(context, L10n.get("scans_open_error"));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  String _subtitle(MakonScan scan) {
    final parts = <String>[];
    if (scan.floorAreaM2 != null) {
      parts.add("~${scan.floorAreaM2!.toStringAsFixed(1)} m²");
    }
    if (scan.floorLongM != null && scan.floorShortM != null) {
      parts.add(
        "${scan.floorLongM!.toStringAsFixed(1)} × "
        "${scan.floorShortM!.toStringAsFixed(1)} m",
      );
    }
    if (scan.glbUrl != null && scan.glbUrl!.isNotEmpty) {
      parts.add("GLB");
    }
    final created = scan.createdAt?.toLocal();
    if (created != null) {
      final y = created.year.toString().padLeft(4, "0");
      final m = created.month.toString().padLeft(2, "0");
      final d = created.day.toString().padLeft(2, "0");
      final hh = created.hour.toString().padLeft(2, "0");
      final mm = created.minute.toString().padLeft(2, "0");
      parts.add("$y-$m-$d $hh:$mm");
    }
    return parts.isEmpty ? L10n.get("scans_no_metrics") : parts.join(" · ");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get("scans_list_title")),
        actions: [
          IconButton(
            tooltip: L10n.get("scans_refresh"),
            onPressed: _loading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_loadedOnce && !widget.isActive) {
      return const SizedBox.shrink();
    }
    if (_loading && _scans == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && (_scans == null || _scans!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L10n.get("scans_load_error"),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => unawaited(_load()),
                child: Text(L10n.get("scans_retry")),
              ),
            ],
          ),
        ),
      );
    }

    final scans = _scans ?? const <MakonScan>[];
    if (scans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            L10n.get("scans_empty"),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        // Extra bottom padding so the last row clears the curved nav.
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: scans.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final scan = scans[index];
          final opening = _openingId == scan.id;
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.view_in_ar,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
            title: Text("${L10n.get("scans_item_title")} #${scan.id}"),
            subtitle: Text(_subtitle(scan)),
            trailing: const Icon(Icons.chevron_right),
            onTap: opening ? null : () => unawaited(_openScan(scan)),
          );
        },
      ),
    );
  }
}
