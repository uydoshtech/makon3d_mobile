import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/makon_analytics.dart";
import "package:makon3d_mobile/services/scan_upload_service.dart";

class ScanShareData {
  const ScanShareData({
    required this.scanId,
    required this.viewerUrl,
    required this.status,
    this.rotationGifUrl,
    this.posterImageUrl,
  });

  final int scanId;
  final String viewerUrl;
  final String status; // pending | processing | ready | failed
  final String? rotationGifUrl;
  final String? posterImageUrl;

  factory ScanShareData.fromJson(Map<String, dynamic> json) {
    return ScanShareData(
      scanId: (json["scanId"] as num?)?.toInt() ?? 0,
      viewerUrl: (json["viewerUrl"] as String?)?.trim() ?? "",
      status: (json["status"] as String?)?.trim() ?? "pending",
      rotationGifUrl: json["rotationGifUrl"] as String?,
      posterImageUrl: json["posterImageUrl"] as String?,
    );
  }

  bool get isGifReady =>
      status == "ready" &&
      rotationGifUrl != null &&
      rotationGifUrl!.trim().isNotEmpty;
}

/// Downloads the cached rotation GIF (when ready) and opens the system share sheet.
class ScanShareService {
  ScanShareService._();

  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPollAttempts = 8; // ~16s

  static Future<ScanShareData> fetchShareData(int scanId) async {
    final response = await Dio(
      BaseOptions(
        baseUrl: ScanUploadService.basePath,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    ).get<Map<String, dynamic>>("/makon3d/scans/$scanId/share");
    return ScanShareData.fromJson(response.data ?? const <String, dynamic>{});
  }

  /// [overlayContext] is used for a lightweight "preparing…" snackbar while polling.
  static Future<void> shareScan(
    int scanId, {
    required String languageCode,
    BuildContext? overlayContext,
  }) async {
    final messenger = overlayContext != null && overlayContext.mounted
        ? ScaffoldMessenger.maybeOf(overlayContext)
        : null;

    MakonAnalytics.log(
      "3d_scan_share_pressed",
      properties: {
        "scanId": scanId,
        "source": "full_screen_3d_viewer",
        "platform": Platform.operatingSystem,
      },
    );

    try {
      var shareData = await fetchShareData(scanId);

      if (!shareData.isGifReady &&
          (shareData.status == "pending" || shareData.status == "processing")) {
        _showSnack(
          messenger,
          L10n.getForLanguage("share_3d_scan_preparing", languageCode),
        );
        shareData = await _pollUntilReadyOrTimeout(scanId, shareData);
      }

      final message = _shareMessage(languageCode, shareData.viewerUrl);

      if (shareData.isGifReady) {
        MakonAnalytics.log(
          "3d_scan_gif_share_started",
          properties: {
            "scanId": scanId,
            "gifStatus": shareData.status,
            "source": "full_screen_3d_viewer",
            "platform": Platform.operatingSystem,
          },
        );
        final gifFile = await _downloadGifToCache(
          scanId: scanId,
          gifUrl: shareData.rotationGifUrl!,
        );
        await SharePlus.instance.share(
          ShareParams(
            text: message,
            files: [
              XFile(
                gifFile.path,
                mimeType: "image/gif",
                name: "makon3d-scan-$scanId.gif",
              ),
            ],
          ),
        );
        MakonAnalytics.log(
          "3d_scan_gif_share_completed",
          properties: {
            "scanId": scanId,
            "gifStatus": "ready",
            "source": "full_screen_3d_viewer",
            "platform": Platform.operatingSystem,
          },
        );
        return;
      }

      // Fallback: poster image (if any) + viewer link, or link only.
      if (shareData.status == "failed") {
        _showSnack(
          messenger,
          L10n.getForLanguage("share_3d_scan_failed", languageCode),
        );
      }

      final posterUrl = shareData.posterImageUrl?.trim();
      if (posterUrl != null && posterUrl.isNotEmpty) {
        try {
          final poster = await _downloadBytesToCache(
            url: posterUrl,
            fileName: "makon3d-scan-$scanId-poster.png",
          );
          await SharePlus.instance.share(
            ShareParams(
              text: message,
              files: [
                XFile(
                  poster.path,
                  mimeType: "image/png",
                  name: "makon3d-scan-$scanId.png",
                ),
              ],
            ),
          );
          MakonAnalytics.log(
            "3d_scan_link_only_shared",
            properties: {
              "scanId": scanId,
              "gifStatus": shareData.status,
              "source": "full_screen_3d_viewer",
              "platform": Platform.operatingSystem,
              "withPoster": true,
            },
          );
          return;
        } catch (e) {
          debugPrint("Poster download for share failed: $e");
        }
      }

      await SharePlus.instance.share(ShareParams(text: message));
      MakonAnalytics.log(
        "3d_scan_link_only_shared",
        properties: {
          "scanId": scanId,
          "gifStatus": shareData.status,
          "source": "full_screen_3d_viewer",
          "platform": Platform.operatingSystem,
          "withPoster": false,
        },
      );
    } catch (e, st) {
      debugPrint("Scan share failed: $e\n$st");
      MakonAnalytics.log(
        "3d_scan_share_failed",
        properties: {
          "scanId": scanId,
          "source": "full_screen_3d_viewer",
          "platform": Platform.operatingSystem,
        },
      );
      // Last-resort: still try to share a constructed viewer URL.
      final fallbackUrl = "https://uydoshtech.github.io/makon3d/?id=$scanId";
      await SharePlus.instance.share(
        ShareParams(text: _shareMessage(languageCode, fallbackUrl)),
      );
    }
  }

  /// Opens the iOS/Android share sheet for a local photogrammetry ZIP
  /// (Save to Files / AirDrop / etc.).
  static Future<void> sharePhotogrammetryPackage(
    String packagePath, {
    int? scanId,
  }) async {
    final file = File(packagePath);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError("Photogrammetry package missing or empty: $packagePath");
    }
    final stem = packagePath.split("/").last;
    final name = scanId != null
        ? "makon3d-photogrammetry-$scanId.zip"
        : stem;
    MakonAnalytics.log(
      "photogrammetry_package_share_pressed",
      properties: {
        "scanId": ?scanId,
        "bytes": file.lengthSync(),
        "platform": Platform.operatingSystem,
      },
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(packagePath, mimeType: "application/zip", name: name),
        ],
        subject: name,
      ),
    );
  }

  static String _shareMessage(String languageCode, String viewerUrl) {
    final intro = L10n.getForLanguage("share_3d_scan_message", languageCode);
    return "$intro\n\n$viewerUrl";
  }

  static void _showSnack(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  static Future<ScanShareData> _pollUntilReadyOrTimeout(
    int scanId,
    ScanShareData initial,
  ) async {
    var current = initial;
    for (var i = 0; i < _maxPollAttempts; i++) {
      if (current.isGifReady || current.status == "failed") return current;
      await Future<void>.delayed(_pollInterval);
      current = await fetchShareData(scanId);
    }
    return current;
  }

  static Future<File> _downloadGifToCache({
    required int scanId,
    required String gifUrl,
  }) {
    return _downloadBytesToCache(
      url: gifUrl,
      fileName: "scan-share-$scanId-rotation.gif",
    );
  }

  static Future<File> _downloadBytesToCache({
    required String url,
    required String fileName,
  }) async {
    final absolute = ScanUploadService.hostedUrl(url);
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$fileName");
    // Reuse cached file when URL unchanged (file name embeds scan id; size > 0).
    if (file.existsSync() && file.lengthSync() > 0) {
      // Soft check: if remote Content-Length differs, re-download.
      try {
        final head = await Dio().head<void>(absolute);
        final len = int.tryParse(head.headers.value("content-length") ?? "");
        if (len != null && len == file.lengthSync()) {
          return file;
        }
      } catch (_) {
        return file;
      }
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
        responseType: ResponseType.bytes,
      ),
    );
    await dio.download(absolute, file.path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      throw StateError("Downloaded share media is missing or empty");
    }
    return file;
  }
}
