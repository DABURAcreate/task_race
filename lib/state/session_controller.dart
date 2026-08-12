import 'dart:async';
import 'package:flutter/foundation.dart';

/// Runs one attempt. Elapsed time is calculated from wall-clock timestamps
/// for each running segment, not by counting ticks — so it stays correct if
/// the app is backgrounded. Pausing banks the elapsed time so far and stops
/// the clock (and the ghost, which races against the same elapsed time);
/// resuming opens a new segment. An interruption — a phone call, getting
/// pulled away — doesn't inflate the recorded time or poison the ghost it
/// feeds, as long as it's paused first.
class SessionController extends ChangeNotifier {
  final int estimateSeconds;
  final int? ghostSeconds; // your previous best, if any
  final VoidCallback? onCrossEstimate; // fires once, the moment you go over

  SessionController({
    required this.estimateSeconds,
    this.ghostSeconds,
    this.onCrossEstimate,
  });

  Duration _accumulated = Duration.zero; // banked time from closed segments
  DateTime? _segmentStartedAt; // non-null while a segment is running
  Timer? _ticker;
  bool _crossedEstimate = false;
  bool _finished = false;

  /// Time banked from segments that have already been paused or stopped —
  /// excludes whatever segment is currently running, if any.
  Duration get bankedElapsed => _accumulated;

  /// When the current running segment began, or null if paused.
  DateTime? get runningSince => _segmentStartedAt;

  Duration get elapsed => _accumulated + _liveSegment;
  Duration get _liveSegment => _segmentStartedAt == null
      ? Duration.zero
      : DateTime.now().difference(_segmentStartedAt!);

  bool get isRunning => _ticker != null;
  bool get isPaused => !isRunning && !_finished;

  /// 0.0 -> 1.0 against your estimate.
  double get progress =>
      (elapsed.inMilliseconds / (estimateSeconds * 1000)).clamp(0.0, 1.0);

  /// 0.0 -> 1.0 against your best time. Fills faster if your best is quick.
  double get ghostProgress {
    if (ghostSeconds == null) return 0;
    return (elapsed.inMilliseconds / (ghostSeconds! * 1000)).clamp(0.0, 1.0);
  }

  bool get ghostFinished => ghostSeconds != null && ghostProgress >= 1.0;
  bool get overEstimate => elapsed.inSeconds > estimateSeconds;

  /// Starts a fresh run.
  void start() {
    if (isRunning || _finished) return;
    _segmentStartedAt = DateTime.now();
    _crossedEstimate = overEstimate;
    _runTicker();
    notifyListeners();
  }

  /// Picks up a session saved mid-run — e.g. one restored after the app
  /// process was killed. [accumulated] is the time already banked;
  /// [runningSince] is when the still-open segment began, or null if the
  /// session was paused when it was saved.
  void restore({required Duration accumulated, DateTime? runningSince}) {
    if (isRunning || _finished) return;
    _accumulated = accumulated;
    _segmentStartedAt = runningSince;
    _crossedEstimate = overEstimate;
    if (runningSince != null) _runTicker();
    notifyListeners();
  }

  /// Stops the clock and banks the time so far. Time spent paused doesn't
  /// count toward the run or the ghost.
  void pause() {
    if (!isRunning) return;
    _accumulated += _liveSegment;
    _segmentStartedAt = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  /// Continues a paused run as a new segment.
  void resume() {
    if (isRunning || _finished) return;
    _segmentStartedAt = DateTime.now();
    _runTicker();
    notifyListeners();
  }

  void _runTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_crossedEstimate && overEstimate) {
        _crossedEstimate = true;
        onCrossEstimate?.call();
      }
      notifyListeners();
    });
  }

  int stop() {
    if (_segmentStartedAt != null) {
      _accumulated += _liveSegment;
      _segmentStartedAt = null;
    }
    _finished = true;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
    return _accumulated.inSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
