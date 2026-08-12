import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/task.dart';

/// Every past run for one task, most recent first — the raw numbers behind
/// the ghost bar and the weekly insights, so a wrong-looking stat can be
/// traced back to the run that caused it.
class HistoryScreen extends StatelessWidget {
  final Task task;

  const HistoryScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final runs = task.runs.toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

    return Scaffold(
      appBar: AppBar(title: Text('${task.name} history')),
      body: runs.isEmpty
          ? const Center(child: Text('No runs yet'))
          : ListView.separated(
              itemCount: runs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _RunTile(run: runs[i]),
            ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final TaskRun run;

  const _RunTile({required this.run});

  @override
  Widget build(BuildContext context) {
    final diff = run.actualSeconds - run.estimateSeconds;
    final won = run.beatEstimate;
    final color = won ? Colors.greenAccent : Colors.redAccent;

    return ListTile(
      leading: Icon(won ? Icons.check_circle : Icons.cancel, color: color),
      title: Text(formatDate(run.finishedAt)),
      subtitle: Text(
        'Guessed ${formatSeconds(run.estimateSeconds)}  •  '
        'Took ${formatSeconds(run.actualSeconds)}  •  '
        '${diff >= 0 ? '+' : '-'}${formatSeconds(diff.abs())}',
      ),
      trailing: Text(
        won ? 'Won' : 'Lost',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
