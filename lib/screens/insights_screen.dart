import 'package:flutter/material.dart';
import '../app.dart';
import '../core/accuracy.dart';
import '../data/insights_dismissal_store.dart';
import '../models/task.dart';

/// Estimate accuracy over the last 7 days, grouped by category rather than
/// by individual task — so a brand-new task inherits a warning from other
/// tasks already timed under the same category.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Map<String, DateTime>? _dismissed;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final dismissed = await InsightsDismissalStore.load();
    if (!mounted) return;
    setState(() => _dismissed = dismissed);
  }

  /// Hides a category's card. Doesn't touch task/run data — the card
  /// reappears once that category has a run more recent than this.
  void _dismissCategory(String category) {
    setState(() => _dismissed = {...?_dismissed, category: DateTime.now()});
    InsightsDismissalStore.dismiss(category);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$category" hidden from weekly insights'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undismissCategory(category),
        ),
      ),
    );
  }

  void _undismissCategory(String category) {
    setState(() => _dismissed = {...?_dismissed}..remove(category));
    InsightsDismissalStore.undismiss(category);
  }

  @override
  Widget build(BuildContext context) {
    final dismissed = _dismissed;
    if (dismissed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final repo = AppScope.of(context).repo;
    // Aggregates read from every task ever created — including deleted ones
    // — so removing a task from your active list doesn't shift a category's
    // historical accuracy. The idle-category list below stays active-only,
    // since a category you can no longer start isn't useful to flag as idle.
    final allTasks = repo.allTasks;
    final activeTasks = repo.tasks;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    final runsByCategory = <String, List<TaskRun>>{};
    final taskIdsByCategory = <String, Set<String>>{};
    for (final task in allTasks) {
      final recentRuns = task.runs
          .where((r) => r.finishedAt.isAfter(cutoff))
          .toList();
      if (recentRuns.isEmpty) continue;
      runsByCategory.putIfAbsent(task.category, () => []).addAll(recentRuns);
      taskIdsByCategory.putIfAbsent(task.category, () => {}).add(task.id);
    }

    final active =
        runsByCategory.entries
            .where((e) {
              final dismissedAt = dismissed[e.key];
              if (dismissedAt == null) return true;
              // A run since the dismissal means there's something new to
              // report, so it un-hides itself.
              return e.value.any((r) => r.finishedAt.isAfter(dismissedAt));
            })
            .map(
              (e) => _CategoryInsight(
                category: e.key,
                ratio: averageAccuracyRatio(e.value)!,
                sessionCount: e.value.length,
                taskCount: taskIdsByCategory[e.key]!.length,
              ),
            )
            .toList()
          ..sort((a, b) => (b.ratio - 1).abs().compareTo((a.ratio - 1).abs()));

    final idleCategories = activeTasks.map((t) => t.category).toSet()
      ..removeAll(runsByCategory.keys);
    final idle = idleCategories.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly insights')),
      body: allTasks.isEmpty
          ? const Center(child: Text('Add a task to see insights'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('No sessions in the last 7 days yet.'),
                  )
                else
                  ...active.map(
                    (insight) => Dismissible(
                      key: ValueKey('insight-${insight.category}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.visibility_off,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      onDismissed: (_) => _dismissCategory(insight.category),
                      child: _InsightCard(insight: insight),
                    ),
                  ),
                if (idle.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'No sessions this week',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ...idle.map(
                    (category) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(category),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CategoryInsight {
  final String category;
  final double ratio;
  final int sessionCount;
  final int taskCount;

  const _CategoryInsight({
    required this.category,
    required this.ratio,
    required this.sessionCount,
    required this.taskCount,
  });
}

class _InsightCard extends StatelessWidget {
  final _CategoryInsight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final pct = ((insight.ratio - 1) * 100).round();
    final String line;
    if (pct > 5) {
      line = 'You underestimate "${insight.category}" by $pct%';
    } else if (pct < -5) {
      line = 'You overestimate "${insight.category}" by ${pct.abs()}%';
    } else {
      line = 'Good guesser on "${insight.category}"';
    }

    final sessions = insight.sessionCount;
    final taskWord = insight.taskCount == 1 ? 'task' : 'tasks';

    return Card(
      child: ListTile(
        title: Text(line),
        subtitle: Text(
          '$sessions session${sessions == 1 ? '' : 's'} this week  •  '
          '${insight.taskCount} $taskWord',
        ),
      ),
    );
  }
}
