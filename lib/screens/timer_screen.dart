import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/active_session_store.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../state/session_controller.dart';
import '../widgets/ghost_bar.dart';
import 'summary_screen.dart';

class TimerScreen extends StatefulWidget {
  final Task task;
  final int estimateSeconds;

  /// Set only when restoring a session already in progress when the app
  /// process was killed. [runningSince] null means it was paused. Null
  /// (the default) means a fresh start.
  final ({int accumulatedSeconds, DateTime? runningSince})? resume;

  const TimerScreen({
    super.key,
    required this.task,
    required this.estimateSeconds,
    this.resume,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with SingleTickerProviderStateMixin {
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
    final resume = widget.resume;
    if (resume == null) {
      _session.start();
    } else {
      _session.restore(
        accumulated: Duration(seconds: resume.accumulatedSeconds),
        runningSince: resume.runningSince,
      );
    }
    _persistSession();
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

  Future<void> _persistSession() {
    return ActiveSessionStore.save(
      ActiveSession(
        taskId: widget.task.id,
        estimateSeconds: widget.estimateSeconds,
        accumulatedSeconds: _session.bankedElapsed.inSeconds,
        runningSince: _session.runningSince,
      ),
    );
  }

  void _togglePause() {
    if (_session.isRunning) {
      _session.pause();
    } else {
      _session.resume();
    }
    _persistSession();
  }

  /// Confirms, then leaves without recording anything: no run saved, no
  /// effect on the streak. For the wrong task started by mistake, or a run
  /// abandoned outright — "Done" always records a run, so it's the wrong
  /// tool for either case.
  Future<void> _cancel() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this run?'),
        content: const Text(
          "Your time won't be saved and it won't count against your streak.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    // dispose() clears the active session store for any non-finished exit,
    // so leaving _finished false here is enough — no separate cleanup.
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
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

    final outcome = scope.streak.apply(
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Discard run',
            onPressed: _cancel,
          ),
          title: Text(widget.task.name),
        ),
        body: Stack(
          children: [
            ListenableBuilder(
              listenable: _session,
              builder: (context, _) {
                final over = _session.overEstimate;
                final paused = _session.isPaused;
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
                            color: over
                                ? Colors.redAccent
                                : paused
                                ? AppColors.label
                                : Colors.white,
                          ),
                        ),
                      ),
                      Text('Estimate ${formatSeconds(widget.estimateSeconds)}'),
                      if (paused)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Paused — not counting against you',
                            style: TextStyle(
                              color: AppColors.label,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                      Opacity(
                        opacity: paused ? 0.5 : 1,
                        child: GhostBar(
                          progress: _session.progress,
                          ghostProgress: _session.ghostProgress,
                          hasGhost: widget.task.bestSeconds != null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_session.ghostFinished)
                        const Text(
                          'Ghost finished. You are behind your record.',
                          style: TextStyle(color: AppColors.label),
                        ),
                      const SizedBox(height: 48),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _togglePause,
                              icon: Icon(
                                _session.isRunning
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              label: Text(
                                _session.isRunning ? 'Pause' : 'Resume',
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _finish,
                              icon: const Icon(Icons.stop),
                              label: const Text('Done'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                            ),
                          ),
                        ],
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
      ),
    );
  }
}
