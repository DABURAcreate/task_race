import 'package:flutter/material.dart';
import '../app.dart';
import '../core/formatters.dart';
import '../models/task.dart';

/// Every past run for one task, most recent first — the raw numbers behind
/// the ghost bar and the weekly insights, so a wrong-looking stat can be
/// traced back to the run that caused it. A single bad run (a forgotten
/// pause, a fat-fingered guess) can set a false personal best that becomes
/// an unbeatable ghost forever, so runs can be corrected or deleted here.
class HistoryScreen extends StatefulWidget {
  final Task task;

  const HistoryScreen({super.key, required this.task});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final runs = widget.task.runs.toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.task.name} history')),
      body: runs.isEmpty
          ? const Center(child: Text('No runs yet'))
          : ListView.separated(
              itemCount: runs.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final run = runs[i];
                return Dismissible(
                  key: ValueKey(run.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) => _confirmDelete(run),
                  onDismissed: (_) => _deleteRun(run),
                  child: _RunTile(run: run, onEdit: () => _editRun(run)),
                );
              },
            ),
    );
  }

  Future<bool> _confirmDelete(TaskRun run) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this run?'),
        content: Text(
          'This removes the ${formatSeconds(run.actualSeconds)} run from '
          '${formatDate(run.finishedAt)}. If it was your personal best, the '
          "ghost recalculates from what's left.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _deleteRun(TaskRun run) {
    setState(() => AppScope.of(context).repo.deleteRun(widget.task.id, run.id));
  }

  Future<void> _editRun(TaskRun run) async {
    final estimateController = TextEditingController(
      text: formatSeconds(run.estimateSeconds),
    );
    final actualController = TextEditingController(
      text: formatSeconds(run.actualSeconds),
    );
    String? error;

    final result = await showDialog<({int estimateSeconds, int actualSeconds})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Correct this run'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: estimateController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'You guessed',
                  hintText: 'mm:ss',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: actualController,
                decoration: const InputDecoration(
                  labelText: 'You took',
                  hintText: 'mm:ss',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final estimate = parseMmSs(estimateController.text);
                final actual = parseMmSs(actualController.text);
                if (estimate == null ||
                    estimate <= 0 ||
                    actual == null ||
                    actual <= 0) {
                  setDialogState(() => error = 'Enter times as mm:ss.');
                  return;
                }
                Navigator.pop(context, (
                  estimateSeconds: estimate,
                  actualSeconds: actual,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(
      () => AppScope.of(context).repo.editRun(
        widget.task.id,
        run.id,
        estimateSeconds: result.estimateSeconds,
        actualSeconds: result.actualSeconds,
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final TaskRun run;
  final VoidCallback onEdit;

  const _RunTile({required this.run, required this.onEdit});

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? 'Won' : 'Lost',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Correct this run',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
