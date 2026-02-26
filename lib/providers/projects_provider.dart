import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import 'database_provider.dart';

final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchProjects();
});

final selectedProjectIdProvider = StateProvider<int?>((ref) => null);

// Project IDs that have received a new message while not focused
final unreadProjectIdsProvider = StateProvider<Set<int>>((ref) => {});

final selectedProjectProvider = Provider<AsyncValue<Project?>>((ref) {
  final id = ref.watch(selectedProjectIdProvider);
  if (id == null) return const AsyncValue.data(null);
  final projectsList = ref.watch(projectsStreamProvider);
  return projectsList.whenData(
    (projects) {
      try {
        return projects.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    },
  );
});

class ProjectsNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<int> createProject({
    required String name,
    String workingDirectory = '',
    String systemPrompt = '',
    String model = 'vllm/claude-sonnet-4-6',
  }) {
    return _db.insertProject(ProjectsCompanion.insert(
      name: name,
      workingDirectory: Value(workingDirectory),
      systemPrompt: Value(systemPrompt),
      model: Value(model),
    ));
  }

  Future<void> updateProject({
    required int id,
    required String name,
    required String workingDirectory,
    required String systemPrompt,
    required String model,
  }) async {
    final existing = await _db.getProject(id);
    await _db.updateProject(ProjectsCompanion(
      id: Value(existing.id),
      name: Value(name),
      workingDirectory: Value(workingDirectory),
      systemPrompt: Value(systemPrompt),
      model: Value(model),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteProject(int id) => _db.deleteProject(id);
}

final projectsNotifierProvider =
    NotifierProvider<ProjectsNotifier, void>(ProjectsNotifier.new);
