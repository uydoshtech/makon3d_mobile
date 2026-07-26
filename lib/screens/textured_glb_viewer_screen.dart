import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/services/scan_upload_service.dart';

class TexturedGlbViewerScreen extends StatelessWidget {
  const TexturedGlbViewerScreen({required this.glbUrl, super.key});

  final String glbUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.get('room_3d_textured'))),
      body: ModelViewer(
        src: ScanUploadService.hostedUrl(glbUrl),
        alt: L10n.get('room_3d_textured'),
        cameraControls: true,
        autoRotate: false,
        backgroundColor: const Color(0xFFF4F2ED),
      ),
    );
  }
}
