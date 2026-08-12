import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../models/task.dart';
import '../state/streak_controller.dart';

class SummaryScreen extends StatelessWidget {
  final Task task;
  final int estimateSeconds;
  final int actualSeconds;
  final StreakOutcome outcome;

  const SummaryScreen({
    super.key,
    required this.task,
    required this.estimateSeconds,
    required this.actualSeconds,
    required this.outcome,
  });

  @override
  Widget build(BuildContext context) {
    final diff = actualSeconds - estimateSeconds;
    final pct = ((diff / estimateSeconds) * 100).round();
    final isRecord = task.bestSeconds == actualSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outcome.beatEstimate ? 'Beat your estimate' : 'Ran over',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            _row('You guessed', formatSeconds(estimateSeconds)),
            _row('You took', formatSeconds(actualSeconds)),
            _row(
              'Difference',
              '${diff >= 0 ? '+' : ''}${formatSeconds(diff.abs())} ($pct%)',
            ),
            const Divider(height: 40),
            _row('Streak', '${outcome.streak}'),
            if (isRecord)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: value.clamp(0, 1),
                      child: child,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amberAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'New record — your ghost just got faster.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Text('Back to tasks'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}