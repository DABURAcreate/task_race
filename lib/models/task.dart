import 'dart:math';

import '../core/accuracy.dart';

/// One completed attempt at a task.
class TaskRun {
  final String id;
  final int estimateSeconds;
  final int actualSeconds;
  final DateTime finishedAt;

  const TaskRun({
    required this.id,
    required this.estimateSeconds,
    required this.actualSeconds,
    required this.finishedAt,
  });

  bool get beatEstimate => actualSeconds <= estimateSeconds;
}

class Task {
  final String id;
  String name;
  String category;
  bool deleted;
  final List<TaskRun> runs;

  Task({
    required this.id,
    required this.name,
    required this.category,
    this.deleted = false,
    List<TaskRun>? runs,
  }) : runs = runs ?? [];

  /// The ghost you race: your fastest time so far.
  int? get bestSeconds =>
      runs.isEmpty ? null : runs.map((r) => r.actualSeconds).reduce(min);

  int? get lastEstimateSeconds =>
      runs.isEmpty ? null : runs.last.estimateSeconds;

  /// 1.0 = perfect guesser. 1.6 = you take 60% longer than you think.
  double? get accuracyRatio => averageAccuracyRatio(runs);
}
