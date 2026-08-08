import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// Expandable inventory of RoomPlan objects detected in a scan.
class DetectedObjectsSection extends StatelessWidget {
  const DetectedObjectsSection({
    required this.counts,
    this.initiallyExpanded = false,
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

  static const _icons = <String, IconData>{
    "window": Icons.window_outlined,
    "door": Icons.door_front_door_outlined,
    "opening": Icons.open_in_full_outlined,
    "storage": Icons.inventory_2_outlined,
    "cabinet": Icons.door_sliding_outlined,
    "bed": Icons.bed_outlined,
    "sofa": Icons.weekend_outlined,
    "table": Icons.table_restaurant_outlined,
    "chair": Icons.chair_outlined,
    "television": Icons.tv_outlined,
    "refrigerator": Icons.kitchen_outlined,
    "sink": Icons.countertops_outlined,
    "toilet": Icons.wc_outlined,
    "bathtub": Icons.bathtub_outlined,
    "shower": Icons.shower_outlined,
    "oven": Icons.microwave_outlined,
    "stove": Icons.soup_kitchen_outlined,
    "dishwasher": Icons.cleaning_services_outlined,
    "washerDryer": Icons.local_laundry_service_outlined,
    "fireplace": Icons.fireplace_outlined,
    "stairs": Icons.stairs_outlined,
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
        leading: const Icon(Icons.tune_rounded, color: MakonColors.black),
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
                  Icon(
                    _icon(entries[index].key),
                    size: 22,
                    color: MakonColors.inkMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _label(entries[index].key),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    "× ${entries[index].value}",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: MakonColors.black,
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

  static IconData _icon(String type) =>
      _icons[type] ?? Icons.category_outlined;

  static String _label(String type) {
    final key = _labelKeys[type];
    if (key != null) return L10n.get(key);
    if (type.isEmpty) return L10n.get("room_scan_stats_object");
    return "${type[0].toUpperCase()}${type.substring(1)}";
  }
}
