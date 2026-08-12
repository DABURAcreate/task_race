import 'package:shared_preferences/shared_preferences.dart';

/// A timer session that was in progress when it was last saved.
class ActiveSession {
  final String taskId;
  final int estimateSeconds;
  final int accumulatedSeconds;

  /// When the still-open segment began, or null if the session was paused
  /// when it was saved.
  final DateTime? runningSince;

  const ActiveSession({
    required this.taskId,
    required this.estimateSeconds,
    required this.accumulatedSeconds,
    this.runningSince,
  });
}

/// Tracks the one timer session currently running, if any, so it can be
/// resumed with the correct elapsed time (and paused/running state) if the
/// app process gets killed mid-run.
class ActiveSessionStore {
  static const _taskIdKey = 'task_race.active_session.task_id';
  static const _estimateKey = 'task_race.active_session.estimate_seconds';
  static const _accumulatedKey = 'task_race.active_session.accumulated_seconds';
  static const _runningSinceKey = 'task_race.active_session.running_since';

  static Future<void> save(ActiveSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskIdKey, session.taskId);
    await prefs.setInt(_estimateKey, session.estimateSeconds);
    await prefs.setInt(_accumulatedKey, session.accumulatedSeconds);
    if (session.runningSince == null) {
      await prefs.remove(_runningSinceKey);
    } else {
      await prefs.setString(
        _runningSinceKey,
        session.runningSince!.toIso8601String(),
      );
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskIdKey);
    await prefs.remove(_estimateKey);
    await prefs.remove(_accumulatedKey);
    await prefs.remove(_runningSinceKey);
  }

  static Future<ActiveSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final taskId = prefs.getString(_taskIdKey);
    final estimateSeconds = prefs.getInt(_estimateKey);
    final accumulatedSeconds = prefs.getInt(_accumulatedKey);
    if (taskId == null ||
        estimateSeconds == null ||
        accumulatedSeconds == null) {
      return null;
    }
    final runningSinceRaw = prefs.getString(_runningSinceKey);
    return ActiveSession(
      taskId: taskId,
      estimateSeconds: estimateSeconds,
      accumulatedSeconds: accumulatedSeconds,
      runningSince: runningSinceRaw == null
          ? null
          : DateTime.parse(runningSinceRaw),
    );
  }
}
