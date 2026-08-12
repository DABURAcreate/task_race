import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

abstract class TaskRepository {
  /// Non-deleted tasks — what the task list shows.
  List<Task> get tasks;

  /// Every task, including soft-deleted ones. Category insights read from
  /// here so tidying up your task list doesn't erase past run history.
  List<Task> get allTasks;

  Task addTask(String name, String category);
  void editTask(String taskId, {required String name, required String category});

  /// Soft delete: hides the task from [tasks] but keeps its runs in
  /// [allTasks] so category-level stats don't shift.
  void deleteTask(String taskId);
  void saveRun(String taskId, TaskRun run);

  /// Populates starter tasks on first run. Resolves once [tasks] reflects
  /// whatever was already on disk (if anything), so callers can await it
  /// before rendering the list.
  Future<void> seed();
}

/// Persists tasks to disk via shared_preferences (as JSON) so they survive
/// an app restart. Reads/writes are mirrored in an in-memory list so the
/// public API stays synchronous — callers don't need to change.
class InMemoryTaskRepository implements TaskRepository {
  static const _prefsKey = 'task_race.tasks';

  InMemoryTaskRepository() {
    _ready = _load();
  }

  final List<Task> _tasks = [];

  /// Completes once the on-disk data (if any) has been loaded into [_tasks].
  late final Future<void> _ready;

  @override
  List<Task> get tasks =>
      List.unmodifiable(_tasks.where((t) => !t.deleted));

  @override
  List<Task> get allTasks => List.unmodifiable(_tasks);

  @override
  Task addTask(String name, String category) {
    final task = Task(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      category: category,
    );
    _tasks.add(task);
    _persist();
    return task;
  }

  @override
  void editTask(String taskId, {required String name, required String category}) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.name = name;
    task.category = category;
    _persist();
  }

  @override
  void deleteTask(String taskId) {
    _tasks.firstWhere((t) => t.id == taskId).deleted = true;
    _persist();
  }

  @override
  void saveRun(String taskId, TaskRun run) {
    _tasks.firstWhere((t) => t.id == taskId).runs.add(run);
    _persist();
  }

  @override
  Future<void> seed() async {
    await _ready;
    if (_tasks.isNotEmpty) return;
    addTask('Studying', 'Studying');
    addTask('Research', 'Research');
    addTask('Work', 'Work');
    addTask('Drawing', 'Drawing');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as List<dynamic>;
    _tasks
      ..clear()
      ..addAll(decoded.map((e) => _taskFromJson(e as Map<String, dynamic>)));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_tasks.map(_taskToJson).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Map<String, dynamic> _taskToJson(Task task) => {
    'id': task.id,
    'name': task.name,
    'category': task.category,
    'deleted': task.deleted,
    'runs': task.runs.map(_runToJson).toList(),
  };

  Task _taskFromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    name: json['name'] as String,
    // Tasks saved before categories existed don't have this key — fall back
    // to the task's own name so each just becomes its own category.
    category: json['category'] as String? ?? json['name'] as String,
    deleted: json['deleted'] as bool? ?? false,
    runs: (json['runs'] as List<dynamic>)
        .map((e) => _runFromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> _runToJson(TaskRun run) => {
    'estimateSeconds': run.estimateSeconds,
    'actualSeconds': run.actualSeconds,
    'finishedAt': run.finishedAt.toIso8601String(),
  };

  TaskRun _runFromJson(Map<String, dynamic> json) => TaskRun(
    estimateSeconds: json['estimateSeconds'] as int,
    actualSeconds: json['actualSeconds'] as int,
    finishedAt: DateTime.parse(json['finishedAt'] as String),
  );
}
