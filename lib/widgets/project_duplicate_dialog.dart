import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/toasts.dart';

/// Long-press copy for a project, matching room-scan duplicate UX:
/// haptic → confirm → blocking progress → independent copy with
/// `{name} — copy` / `{name} — copy 2` naming.
Future<void> confirmAndDuplicateProject(
  BuildContext context,
  MakonProject project,
) async {
  unawaited(HapticFeedback.mediumImpact());
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.copy_all_outlined),
      title: Text(L10n.get('project_duplicate_confirm_title')),
      content: Text(
        L10n.get(
          'project_duplicate_confirm_message',
        ).replaceAll('{name}', project.name),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(L10n.get('project_delete_cancel')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.copy_outlined),
          label: Text(L10n.get('project_duplicate_confirm')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  BuildContext? progressContext;
  final progressClosed = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      progressContext = dialogContext;
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 18),
              Expanded(child: Text(L10n.get('project_duplicate_progress'))),
            ],
          ),
        ),
      );
    },
  );
  await WidgetsBinding.instance.endOfFrame;

  MakonProject? duplicate;
  Object? duplicateError;
  try {
    duplicate = await MakonProjectStore.instance.duplicateProject(
      projectId: project.id,
      duplicateName: uniqueProjectCopyName(
        sourceName: project.name,
        existingNames: MakonProjectStore.instance.projects.map(
          (candidate) => candidate.name,
        ),
      ),
    );
  } catch (error) {
    duplicateError = error;
  } finally {
    final dialogContext = progressContext;
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    await progressClosed;
  }
  if (!context.mounted) return;
  if (duplicate != null) {
    Toasts.showSuccess(context, L10n.get('project_duplicate_success'));
  } else {
    debugPrint('Project duplication failed: $duplicateError');
    Toasts.showError(context, L10n.get('project_duplicate_failed'));
  }
}

@visibleForTesting
String uniqueProjectCopyName({
  required String sourceName,
  required Iterable<String> existingNames,
}) {
  final firstCopy = L10n.get(
    'project_duplicate_name',
  ).replaceAll('{name}', sourceName.trim());
  final usedNames = {
    for (final name in existingNames) name.trim().toLowerCase(),
  };
  if (!usedNames.contains(firstCopy.toLowerCase())) return firstCopy;
  var number = 2;
  while (usedNames.contains('$firstCopy $number'.toLowerCase())) {
    number += 1;
  }
  return '$firstCopy $number';
}
