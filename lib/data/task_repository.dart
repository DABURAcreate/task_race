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
  void editTask(
    String taskId, {
    required String name,
    required String category,
  });

  /// Renames a category across every task that has it — including
  /// soft-deleted ones — so a rename doesn't fragment that category's
  /// accuracy history under two names.
  void renameCategory(String oldCategory, String newCategory);

  /// Soft delete: hides the task from [tasks] but keeps its runs in
  /// [allTasks] so category-level stats don't shift.
  void deleteTask(String taskId);

  /// Soft delete every task in [category] at once — the category-level
  /// equivalent of [deleteTask]. Their runs stay in [allTasks] too.
  void deleteCategory(String category);
  void saveRun(String taskId, TaskRun run);

  /// Removes a single run — e.g. one that was mid-timer when the timer got
  /// bumped, quietly setting a false personal best that would otherwise
  /// become an unbeatable ghost forever.
  void deleteRun(String taskId, String runId);

  /// Corrects a run's recorded times in place, keeping its id and date.
  void editRun(
    String taskId,
    String runId, {
    required int estimateSeconds,
    required int actualSeconds,
  });

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
  List<Task> get tasks => List.unmodifiable(_tasks.where((t) => !t.deleted));

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
  void editTask(
    String taskId, {
    required String name,
    required String category,
  }) {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    task.name = name;
    task.category = category;
    _persist();
  }

  @override
  void renameCategory(String oldCategory, String newCategory) {
    if (oldCategory == newCategory) return;
    for (final task in _tasks) {
      if (task.category == oldCategory) task.category = newCategory;
    }
    _persist();
  }

  @override
  void deleteTask(String taskId) {
    _tasks.firstWhere((t) => t.id == taskId).deleted = true;
    _persist();
  }

  @override
  void deleteCategory(String category) {
    for (final task in _tasks) {
      if (task.category == category) task.deleted = true;
    }
    _persist();
  }

  @override
  void saveRun(String taskId, TaskRun run) {
    _tasks.firstWhere((t) => t.id == taskId).runs.add(run);
    _persist();
  }

  @override
  void deleteRun(String taskId, String runId) {
    _tasks
        .firstWhere((t) => t.id == taskId)
        .runs
        .removeWhere((r) => r.id == runId);
    _persist();
  }

  @override
  void editRun(
    String taskId,
    String runId, {
    required int estimateSeconds,
    required int actualSeconds,
  }) {
    final runs = _tasks.firstWhere((t) => t.id == taskId).runs;
    final index = runs.indexWhere((r) => r.id == runId);
    if (index == -1) return;
    runs[index] = TaskRun(
      id: runId,
      estimateSeconds: estimateSeconds,
      actualSeconds: actualSeconds,
      finishedAt: runs[index].finishedAt,
    );
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
    'id': run.id,
    'estimateSeconds': run.estimateSeconds,
    'actualSeconds': run.actualSeconds,
    'finishedAt': run.finishedAt.toIso8601String(),
  };

  TaskRun _runFromJson(Map<String, dynamic> json) {
    final finishedAt = DateTime.parse(json['finishedAt'] as String);
    return TaskRun(
      // Runs saved before per-run ids existed don't have this key — fall
      // back to the finish timestamp, which was already effectively unique.
      id: json['id'] as String? ?? finishedAt.microsecondsSinceEpoch.toString(),
      estimateSeconds: json['estimateSeconds'] as int,
      actualSeconds: json['actualSeconds'] as int,
      finishedAt: finishedAt,
    );
  }
}
