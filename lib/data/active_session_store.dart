import 'package:shared_preferences/shared_preferences.dart';

/// A timer session that was in progress when it was last saved.
class ActiveSession {
  final String taskId;
  final int estimateSeconds;
  final DateTime startedAt;

  const ActiveSession({
    required this.taskId,
    required this.estimateSeconds,
    required this.startedAt,
  });
}

/// Tracks the one timer session currently running, if any, so it can be
/// resumed with the correct elapsed time if the app process gets killed
/// mid-run.
class ActiveSessionStore {
  static const _taskIdKey = 'task_race.active_session.task_id';
  static const _estimateKey = 'task_race.active_session.estimate_seconds';
  static const _startedAtKey = 'task_race.active_session.started_at';

  static Future<void> save(ActiveSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskIdKey, session.taskId);
    await prefs.setInt(_estimateKey, session.estimateSeconds);
    await prefs.setString(_startedAtKey, session.startedAt.toIso8601String());
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskIdKey);
    await prefs.remove(_estimateKey);
    await prefs.remove(_startedAtKey);
  }

  static Future<ActiveSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final taskId = prefs.getString(_taskIdKey);
    final estimateSeconds = prefs.getInt(_estimateKey);
    final startedAtRaw = prefs.getString(_startedAtKey);
    if (taskId == null || estimateSeconds == null || startedAtRaw == null) {
      return null;
    }
    return ActiveSession(
      taskId: taskId,
      estimateSeconds: estimateSeconds,
      startedAt: DateTime.parse(startedAtRaw),
    );
  }
}
