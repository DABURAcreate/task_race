import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../core/formatters.dart';
import '../data/active_session_store.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../state/session_controller.dart';
import '../widgets/ghost_bar.dart';
import 'summary_screen.dart';

class TimerScreen extends StatefulWidget {
  final Task task;
  final int estimateSeconds;

  /// If this session is being restored (e.g. the app was killed mid-run),
  /// the timestamp it originally started at. Null for a fresh start.
  final DateTime? resumeStartedAt;

  const TimerScreen({
    super.key,
    required this.task,
    required this.estimateSeconds,
    this.resumeStartedAt,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
  late final DateTime _startedAt = widget.resumeStartedAt ?? DateTime.now();
  late final SessionController _session = SessionController(
    estimateSeconds: widget.estimateSeconds,
    ghostSeconds: widget.task.bestSeconds,
    onCrossEstimate: _notifyOverEstimate,
  );
  bool _finished = false;

  // Plays once, right at the moment you cross your estimate: a red screen
  // flash and a quick punch on the digits, timed with the haptic buzz.
  late final AnimationController _crossAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _flashOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.5), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.0), weight: 75),
  ]).animate(CurvedAnimation(parent: _crossAnim, curve: Curves.easeOut));
  late final Animation<double> _digitScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 75),
  ]).animate(CurvedAnimation(parent: _crossAnim, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    NotificationService.instance.requestPermissionOnce();
    ActiveSessionStore.save(
      ActiveSession(
        taskId: widget.task.id,
        estimateSeconds: widget.estimateSeconds,
        startedAt: _startedAt,
      ),
    );
    _session.start(startedAt: _startedAt);
  }

  @override
  void dispose() {
    _session.dispose();
    _crossAnim.dispose();
    // If the timer wasn't finished (e.g. the user backed out), don't leave
    // a stale entry that would wrongly resume this session on next launch.
    if (!_finished) {
      ActiveSessionStore.clear();
    }
    super.dispose();
  }

  void _notifyOverEstimate() {
    HapticFeedback.mediumImpact();
    _crossAnim.forward(from: 0);
    NotificationService.instance.showOverEstimate(
      taskName: widget.task.name,
      estimateLabel: formatSeconds(widget.estimateSeconds),
    );
  }

  void _finish() {
    _finished = true;
    ActiveSessionStore.clear();
    final actual = _session.stop();
    final scope = AppScope.of(context);

    scope.repo.saveRun(
      widget.task.id,
      TaskRun(
        estimateSeconds: widget.estimateSeconds,
        actualSeconds: actual,
        finishedAt: DateTime.now(),
      ),
    );

    final outcome = scope.stakes.apply(
      estimate: widget.estimateSeconds,
      actual: actual,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(
          task: widget.task,
          estimateSeconds: widget.estimateSeconds,
          actualSeconds: actual,
          outcome: outcome,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task.name)),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _session,
            builder: (context, _) {
              final over = _session.overEstimate;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _digitScale,
                      child: Text(
                        formatDuration(_session.elapsed),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w300,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: over ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                    Text('Estimate ${formatSeconds(widget.estimateSeconds)}'),
                    const SizedBox(height: 40),
                    GhostBar(
                      progress: _session.progress,
                      ghostProgress: _session.ghostProgress,
                      hasGhost: widget.task.bestSeconds != null,
                    ),
                    const SizedBox(height: 16),
                    if (_session.ghostFinished)
                      const Text(
                        'Ghost finished. You are behind your record.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      onPressed: _finish,
                      icon: const Icon(Icons.stop),
                      label: const Text('Done'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashOpacity,
                builder: (context, _) => Container(
                  color: Colors.redAccent.withValues(
                    alpha: _flashOpacity.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}