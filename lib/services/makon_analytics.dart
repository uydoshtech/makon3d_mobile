import 'package:flutter/foundation.dart';
import 'package:room_scan_kit/scan_flow/scan_flow.dart';

/// Lightweight Makon analytics sink (debug log today; swap for Firebase later).
///
/// Never send full address or private project notes.
class MakonAnalytics {
  MakonAnalytics._();

  static void log(String event, {Map<String, Object?> properties = const {}}) {
    final safe = <String, Object?>{
      for (final e in properties.entries)
        if (!_isSensitive(e.key)) e.key: e.value,
    };
    debugPrint('[makon_analytics] $event $safe');
  }

  static bool _isSensitive(String key) {
    final k = key.toLowerCase();
    return k.contains('address') ||
        k.contains('note') ||
        k.contains('email') ||
        k.contains('phone');
  }

  static void scanModeScreenViewed({
    String? projectId,
    String entryPoint = 'new_project',
  }) {
    log(
      'makon_scan_mode_screen_viewed',
      properties: {
        if (projectId != null) 'project_id': projectId,
        'entry_point': entryPoint,
      },
    );
  }

  static void scanModeSelected({
    required String projectId,
    required ScanMode scanMode,
    String entryPoint = 'new_project',
  }) {
    log(
      'makon_scan_mode_selected',
      properties: {
        'project_id': projectId,
        'scan_mode': scanMode.wireValue,
        'entry_point': entryPoint,
      },
    );
  }

  static void entireHousingScanStarted({
    required String projectId,
    String entryPoint = 'project_dashboard',
  }) {
    log(
      'makon_entire_housing_scan_started',
      properties: {
        'project_id': projectId,
        'scan_mode': ScanMode.entireHousing.wireValue,
        'entry_point': entryPoint,
      },
    );
  }

  static void roomByRoomStarted({
    required String projectId,
    String entryPoint = 'project_dashboard',
  }) {
    log(
      'makon_room_by_room_started',
      properties: {
        'project_id': projectId,
        'scan_mode': ScanMode.roomByRoom.wireValue,
        'entry_point': entryPoint,
      },
    );
  }
}
