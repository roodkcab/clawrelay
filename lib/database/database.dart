import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get workingDirectory => text().withDefault(const Constant(''))();
  TextColumn get systemPrompt => text().withDefault(const Constant(''))();
  TextColumn get model =>
      text().withDefault(const Constant('vllm/claude-sonnet-4-6'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // user, assistant, system
  TextColumn get content => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Projects, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  static AppDatabase? _instance;

  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'clawrelay.sqlite'));
    _instance = AppDatabase._internal(NativeDatabase.createInBackground(file));
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  // -- Projects CRUD --

  Future<List<Project>> allProjects() =>
      (select(projects)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Stream<List<Project>> watchProjects() =>
      (select(projects)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<Project> getProject(int id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  Future<bool> updateProject(ProjectsCompanion entry) =>
      update(projects).replace(entry.copyWith(updatedAt: Value(DateTime.now())));

  Future<int> deleteProject(int id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  // -- Messages CRUD --

  Future<List<Message>> messagesForProject(int projectId) =>
      (select(messages)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<List<Message>> recentMessagesForProject(int projectId,
      {int limit = 50}) async {
    final rows = await (select(messages)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
    return rows.reversed.toList();
  }

  Stream<List<Message>> watchMessages(int projectId) =>
      (select(messages)
            ..where((t) => t.projectId.equals(projectId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<int> insertMessage(MessagesCompanion entry) =>
      into(messages).insert(entry);

  Future<int> deleteMessagesForProject(int projectId) =>
      (delete(messages)..where((t) => t.projectId.equals(projectId))).go();
}
