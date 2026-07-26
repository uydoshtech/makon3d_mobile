import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/room_type.dart';

/// Pick a room type before starting a room-by-room scan.
class RoomTypeSelectionScreen extends StatelessWidget {
  const RoomTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.get('room_type_select_title'))),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: RoomType.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final type = RoomType.values[index];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: Icon(type.icon),
            title: Text(L10n.get(type.titleKey)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pop(type),
          );
        },
      ),
    );
  }
}
