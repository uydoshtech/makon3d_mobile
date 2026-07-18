import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/screens/project_dashboard_screen.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';

/// Device-local Makon projects. Opening a project never re-asks for scan mode.
class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({
    super.key,
    this.isActive = false,
    this.onCreateProject,
  });

  final bool isActive;

  /// Hosted by [MainShell] so the + FAB sits above the curved tab bar.
  final VoidCallback? onCreateProject;

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  @override
  void initState() {
    super.initState();
    MakonProjectStore.instance.addListener(_onChanged);
    unawaited(MakonProjectStore.instance.ensureLoaded());
  }

  @override
  void dispose() {
    MakonProjectStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openProject(MakonProject project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDashboardScreen(projectId: project.id),
      ),
    );
  }

  String _subtitle(MakonProject project) {
    final mode = L10n.get(project.scanMode.titleKey);
    final address = project.address?.trim();
    if (address != null && address.isNotEmpty) {
      return '$mode · $address';
    }
    return mode;
  }

  @override
  Widget build(BuildContext context) {
    final store = MakonProjectStore.instance;
    final projects = store.projects;
    final onCreate = widget.onCreateProject;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get('projects_list_title')),
        actions: [
          if (onCreate != null)
            IconButton(
              tooltip: L10n.get('project_new_title'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: !store.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          L10n.get('projects_empty'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (onCreate != null) ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: onCreate,
                            icon: const Icon(Icons.add),
                            label: Text(L10n.get('project_new_title')),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      title: Text(project.name),
                      subtitle: Text(_subtitle(project)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => unawaited(_openProject(project)),
                    );
                  },
                ),
    );
  }
}
