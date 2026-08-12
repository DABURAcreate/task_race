import '../models/task.dart';

/// 1.0 = perfect guesser. 1.6 = actual time averaged 60% longer than
/// estimated. Null if [runs] is empty.
double? averageAccuracyRatio(Iterable<TaskRun> runs) {
  var count = 0;
  var sum = 0.0;
  for (final r in runs) {
    sum += r.actualSeconds / r.estimateSeconds;
    count++;
  }
  return count == 0 ? null : sum / count;
}

/// Turns an [averageAccuracyRatio] into the "you under/overestimate" line
/// shown next to a task or category. Within 5% either way counts as good.
String describeAccuracy(double ratio) {
  final pct = ((ratio - 1) * 100).round();
  if (pct > 5) return 'You underestimate by $pct%';
  if (pct < -5) return 'You overestimate by ${pct.abs()}%';
  return 'Good guesser';
}
