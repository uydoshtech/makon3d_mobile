import 'dart:async';

import 'package:flutter/material.dart';

import 'package:makon3d_mobile/l10n/l10n.dart';
import 'package:makon3d_mobile/models/contractor_listing.dart';
import 'package:makon3d_mobile/models/makon_project.dart';
import 'package:makon3d_mobile/screens/project_dashboard_screen.dart';
import 'package:makon3d_mobile/services/auth/auth_state.dart';
import 'package:makon3d_mobile/services/makon_project_store.dart';
import 'package:makon3d_mobile/widgets/app_bar_account_avatar.dart';
import 'package:makon3d_mobile/widgets/project_delete_dialog.dart';
import 'package:makon3d_mobile/widgets/sign_in_sheet.dart';

/// Device-local Makon projects. Opening a project never re-asks for scan mode.
class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({
    super.key,
    this.isActive = false,
    this.onCreateProject,
    this.onOpenAccount,
  });

  final bool isActive;

  /// Hosted by [MainShell] so the + FAB sits above the curved tab bar.
  final VoidCallback? onCreateProject;

  /// Opens the Account section in the shell's Settings tab.
  final VoidCallback? onOpenAccount;

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  @override
  void initState() {
    super.initState();
    MakonProjectStore.instance.addListener(_onChanged);
    AuthState().addListener(_onChanged);
    unawaited(MakonProjectStore.instance.ensureLoaded());
  }

  @override
  void dispose() {
    MakonProjectStore.instance.removeListener(_onChanged);
    AuthState().removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() => MakonProjectStore.instance.refreshFromRemote();

  Future<void> _openProject(MakonProject project) async {
    if (!AuthState().isSignedIn) {
      await SignInSheet.show(context);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDashboardScreen(projectId: project.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = MakonProjectStore.instance;
    final projects = store.projects;
    final onCreate = widget.onCreateProject;
    final isSignedIn = AuthState().isSignedIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.get('projects_list_title')),
        actions: [
          if (widget.onOpenAccount case final onOpenAccount?)
            AppBarAccountAvatar(onTap: onOpenAccount),
        ],
      ),
      body: !isSignedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      L10n.get('projects_sign_in_required'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        SignInSheet.show(context);
                      },
                      child: Text(L10n.get('settings_sign_in')),
                    ),
                  ],
                ),
              ),
            )
          : !store.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: projects.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  32,
                                  32,
                                  32,
                                  120,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      L10n.get('projects_empty'),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                    if (onCreate != null) ...[
                                      const SizedBox(height: 20),
                                      FilledButton.icon(
                                        onPressed: onCreate,
                                        icon: const Icon(Icons.add),
                                        label: Text(
                                          L10n.get('project_new_title'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        final theme = Theme.of(context);
                        return Dismissible(
                          key: ValueKey(project.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) =>
                              confirmDeleteProject(context, project),
                          onDismissed: (_) =>
                              unawaited(deleteProject(context, project)),
                          background: Container(
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.only(right: 20),
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onError,
                            ),
                          ),
                          child: _ProjectCard(
                            project: project,
                            onTap: () => unawaited(_openProject(project)),
                            onLongPress: () => unawaited(
                              confirmAndDeleteProject(context, project),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onLongPress,
  });

  final MakonProject project;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = project.address?.trim();
    final notes = project.notes?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    final hasNotes = notes != null && notes.isNotEmpty;
    final scannedRooms = project.rooms
        .where((room) => room.isScanned)
        .toList(growable: false);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.folder_copy_outlined,
                  color: theme.colorScheme.onSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (scannedRooms.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...scannedRooms.map((room) {
                        final name = room.name?.trim();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _MetadataLine(
                            icon: room.roomType.icon,
                            text: name != null && name.isNotEmpty
                                ? name
                                : L10n.get(room.roomType.titleKey),
                          ),
                        );
                      }),
                    ],
                    if (hasAddress) ...[
                      const SizedBox(height: 4),
                      _MetadataLine(
                        icon: Icons.location_on_outlined,
                        text: address,
                      ),
                    ],
                    if (hasNotes) ...[
                      const SizedBox(height: 4),
                      _MetadataLine(icon: Icons.notes_outlined, text: notes),
                    ],
                    if (project.contractorListing case final listing?) ...[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color:
                                    listing.status ==
                                        ContractorListingStatus.open
                                    ? const Color(0xFF2E7D32)
                                    : theme.colorScheme.onSurfaceVariant,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${L10n.get(switch (listing.status) {
                                  ContractorListingStatus.open => 'contractor_status_searching',
                                  ContractorListingStatus.assigned => 'contractor_status_assigned',
                                  ContractorListingStatus.closed || ContractorListingStatus.cancelled => 'contractor_status_closed',
                                })} · '
                                '${L10n.get('contractor_responses_short').replaceAll('{count}', '${listing.responseCount}')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
