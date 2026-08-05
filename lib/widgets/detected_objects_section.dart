import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Expandable inventory of RoomPlan objects detected in a scan.
class DetectedObjectsSection extends StatelessWidget {
  const DetectedObjectsSection({
    required this.counts,
    this.initiallyExpanded = true,
    super.key,
  });

  final Map<String, int> counts;
  final bool initiallyExpanded;

  static const _labelKeys = <String, String>{
    "window": "room_scan_stats_windows",
    "door": "room_scan_stats_doors",
    "opening": "room_scan_stats_openings",
    "storage": "room_scan_stats_storage",
    "cabinet": "room_scan_stats_cabinet",
    "bed": "room_scan_stats_bed",
    "sofa": "room_scan_stats_sofa",
    "table": "room_scan_stats_table",
    "chair": "room_scan_stats_chair",
    "television": "room_scan_stats_television",
    "refrigerator": "room_scan_stats_refrigerator",
    "sink": "room_scan_stats_sink",
    "toilet": "room_scan_stats_toilet",
    "bathtub": "room_scan_stats_bathtub",
    "shower": "room_scan_stats_shower",
    "oven": "room_scan_stats_oven",
    "stove": "room_scan_stats_stove",
    "dishwasher": "room_scan_stats_dishwasher",
    "washerDryer": "room_scan_stats_washer_dryer",
    "fireplace": "room_scan_stats_fireplace",
    "stairs": "room_scan_stats_stairs",
  };

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key("detected_objects_section"),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        leading: const Icon(Icons.tune_rounded, color: MakonColors.yellow),
        title: Text(
          L10n.get("project_detected_objects"),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(entries[index].key),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    "× ${entries[index].value}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: MakonColors.yellow,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _label(String type) {
    final key = _labelKeys[type];
    if (key != null) return L10n.get(key);
    if (type.isEmpty) return L10n.get("room_scan_stats_object");
    return "${type[0].toUpperCase()}${type.substring(1)}";
  }
}
