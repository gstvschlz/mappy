import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import 'active_project.dart';
import 'project_detail.dart';
import 'project_icons.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(allProjectsStreamProvider);
    final activeAsync = ref.watch(activeProjectProvider);
    final activeId = activeAsync.value?.id;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewProjectSheet(context, ref),
        icon: const Icon(CupertinoIcons.add),
        label: const Text('New project'),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projects) {
          if (projects.isEmpty) {
            return const _EmptyState();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      for (var i = 0; i < projects.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 56),
                            child: Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: scheme.onSurface.withValues(alpha: 0.08),
                            ),
                          ),
                        _ProjectRow(
                          project: projects[i],
                          isActive: projects[i].id == activeId,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProjectDetailScreen(project: projects[i]),
                            ),
                          ),
                          onActivate: () => ref
                              .read(activeProjectProvider.notifier)
                              .setActive(projects[i].id),
                          onRename: () =>
                              _showRenameSheet(context, ref, projects[i]),
                          onPickIcon: () =>
                              _pickIcon(context, ref, projects[i]),
                          onDelete: () =>
                              _confirmDelete(context, ref, projects[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Tap a project to view its photos and observations. '
                  'Long-press the menu icon for actions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNewProjectSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<_NewProjectResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NewProjectSheet(controller: controller),
    );
    if (result == null || result.name.trim().isEmpty) return;
    final db = ref.read(appDatabaseProvider);
    final project = Project(
      id: const Uuid().v4(),
      name: result.name.trim(),
      createdAt: DateTime.now(),
      iconName: result.iconName,
    );
    await db.projectDao.insert(project);
    await ref.read(activeProjectProvider.notifier).setActive(project.id);
  }

  Future<void> _showRenameSheet(
      BuildContext context, WidgetRef ref, Project project) async {
    final controller = TextEditingController(text: project.name);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NameSheet(
        title: 'Rename project',
        controller: controller,
        actionLabel: 'Save',
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final db = ref.read(appDatabaseProvider);
    await db.projectDao.updateProject(project.copyWith(name: name.trim()));
  }

  Future<void> _pickIcon(
      BuildContext context, WidgetRef ref, Project project) async {
    final picked = await pickProjectIcon(context, current: project.iconName);
    if (picked == null) return;
    final db = ref.read(appDatabaseProvider);
    await db.projectDao.updateProject(project.copyWith(
      iconName: Value(picked),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Project project) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Delete "${project.name}"?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'All observations, photos, and tracks in this project will be permanently removed.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(appDatabaseProvider);
    await db.projectDao.deleteById(project.id);
    final active = ref.read(activeProjectProvider).value;
    if (active?.id == project.id) {
      await ref.read(activeProjectProvider.notifier).clear();
    }
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.isActive,
    required this.onTap,
    required this.onActivate,
    required this.onRename,
    required this.onPickIcon,
    required this.onDelete,
  });

  final Project project;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onPickIcon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isActive ? scheme.primary : scheme.onSurfaceVariant)
                    .withValues(alpha: isActive ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                resolveProjectIcon(project.iconName),
                size: 18,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? 'Active project'
                        : project.createdAt.toLocal().toString().split(' ').first,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            _ActionsButton(
              isActive: isActive,
              onActivate: onActivate,
              onRename: onRename,
              onPickIcon: onPickIcon,
              onDelete: onDelete,
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsButton extends StatelessWidget {
  const _ActionsButton({
    required this.isActive,
    required this.onActivate,
    required this.onRename,
    required this.onPickIcon,
    required this.onDelete,
  });

  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onPickIcon;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(CupertinoIcons.ellipsis_circle),
      iconSize: 22,
      onPressed: () => _showActions(context),
    );
  }

  void _showActions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (!isActive)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                onActivate();
              },
              child: const Text('Set as active project'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onRename();
            },
            child: const Text('Rename'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              onPickIcon();
            },
            child: const Text('Change icon'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _NewProjectResult {
  const _NewProjectResult({required this.name, required this.iconName});
  final String name;
  final String? iconName;
}

class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet({required this.controller});
  final TextEditingController controller;

  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  String _iconName = 'folder';

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'New project',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await pickProjectIcon(
                    context,
                    current: _iconName,
                  );
                  if (picked != null) setState(() => _iconName = picked);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    resolveProjectIcon(_iconName),
                    color: scheme.primary,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Project name',
                  ),
                  onSubmitted: (v) => Navigator.pop(
                    context,
                    _NewProjectResult(name: v, iconName: _iconName),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _NewProjectResult(
                name: widget.controller.text,
                iconName: _iconName,
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _NameSheet extends StatelessWidget {
  const _NameSheet({
    required this.title,
    required this.controller,
    required this.actionLabel,
  });

  final String title;
  final TextEditingController controller;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Project name',
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                CupertinoIcons.folder_fill,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Create one to start mapping observations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
