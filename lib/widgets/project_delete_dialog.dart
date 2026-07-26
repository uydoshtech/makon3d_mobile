import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Confirm-then-delete for a project. Deleting removes the local project,
/// its backend backup, its uploaded scans from the public gallery, and its
/// local USDZ files (see [MakonProjectStore.delete]). Returns true when the
/// project was actually deleted.
Future<bool> confirmAndDeleteProject(
  BuildContext context,
  MakonProject project,
) async {
  if (!await confirmDeleteProject(context, project)) return false;
  if (!context.mounted) return false;
  await deleteProject(context, project);
  return true;
}

/// Displays confirmation before a project deletion.
Future<bool> confirmDeleteProject(
  BuildContext context,
  MakonProject project,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(L10n.get('project_delete_confirm_title')),
        content: Text(
          L10n.get(
            'project_delete_confirm_message',
          ).replaceAll('{name}', project.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(L10n.get('project_delete_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(L10n.get('project_delete_confirm')),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

/// Deletes a confirmed project and presents a success message.
Future<void> deleteProject(BuildContext context, MakonProject project) async {
  await MakonProjectStore.instance.delete(project.id);
  if (context.mounted) {
    Toasts.showSuccess(context, L10n.get('project_deleted'));
  }
}
