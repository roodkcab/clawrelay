import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/projects_provider.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/project_tile.dart';
import 'chat_screen.dart';
import 'project_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        final sidebar = _ProjectList(
          selectedId: selectedId,
          onSelect: (project) {
            ref.read(selectedProjectIdProvider.notifier).state = project.id;
            // Clear unread mark when opening this project
            final unread = ref.read(unreadProjectIdsProvider);
            if (unread.contains(project.id)) {
              ref.read(unreadProjectIdsProvider.notifier).state =
                  unread.difference({project.id});
            }
            if (!isWide) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    project: project,
                    showBackButton: true,
                  ),
                ),
              );
            }
          },
        );

        Widget? detail;
        if (selectedId != null) {
          detail = projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (projects) {
              try {
                final project = projects.firstWhere((p) => p.id == selectedId);
                return ChatScreen(project: project);
              } catch (_) {
                return const Center(child: Text('Project not found'));
              }
            },
          );
        }

        return AdaptiveLayout(
          sidebar: sidebar,
          detail: isWide ? detail : null,
          emptyDetail: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'Select a project to start chatting',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProjectList extends ConsumerWidget {
  final int? selectedId;
  final void Function(Project) onSelect;

  const _ProjectList({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsStreamProvider);
    final unreadIds = ref.watch(unreadProjectIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ClawRelay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProjectFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'No projects yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create one',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ProjectTile(
                project: project,
                selected: project.id == selectedId,
                hasUnread: unreadIds.contains(project.id),
                onTap: () => onSelect(project),
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectFormScreen(project: project),
                  ),
                ),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete project?'),
                      content: Text(
                          'Delete "${project.name}" and all its messages?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref
                        .read(projectsNotifierProvider.notifier)
                        .deleteProject(project.id);
                    if (selectedId == project.id) {
                      ref.read(selectedProjectIdProvider.notifier).state = null;
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
