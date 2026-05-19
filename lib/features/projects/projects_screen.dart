import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';
import 'active_project.dart';
import 'project_detail.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(allProjectsStreamProvider);
    final activeAsync = ref.watch(activeProjectProvider);
    final activeId = activeAsync.value?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewProjectSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projects) {
          if (projects.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final p = projects[i];
              final isActive = p.id == activeId;
              return ListTile(
                leading: Icon(
                  isActive ? Icons.radio_button_checked : Icons.folder_outlined,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(p.name),
                subtitle: Text(
                  'Created ${p.createdAt.toLocal().toString().split('.').first}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (!isActive)
                      TextButton(
                        onPressed: () => ref
                            .read(activeProjectProvider.notifier)
                            .setActive(p.id),
                        child: const Text('Activate'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showRenameSheet(context, ref, p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(context, ref, p),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(project: p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showNewProjectSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NameSheet(
        title: 'New project',
        controller: controller,
        actionLabel: 'Create',
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final db = ref.read(appDatabaseProvider);
    final project = Project(
      id: const Uuid().v4(),
      name: name.trim(),
      createdAt: DateTime.now(),
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${project.name}"?'),
        content: const Text(
          'All observations, photos, and tracks in this project will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          const SizedBox(height: 12),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No projects yet.\nCreate one to start mapping observations.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
