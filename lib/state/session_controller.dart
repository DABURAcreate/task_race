import 'dart:async';
import 'package:flutter/foundation.dart';

/// Runs one attempt. Elapsed time is calculated from a start timestamp,
/// not by counting ticks — so it stays correct if the app is backgrounded.
class SessionController extends ChangeNotifier {
  final int estimateSeconds;
  final int? ghostSeconds; // your previous best, if any
  final VoidCallback? onCrossEstimate; // fires once, the moment you go over

  SessionController({
    required this.estimateSeconds,
    this.ghostSeconds,
    this.onCrossEstimate,
  });

  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _crossedEstimate = false;

  Duration get elapsed => _elapsed;
  bool get isRunning => _ticker != null;

  /// 0.0 -> 1.0 against your estimate.
  double get progress =>
      (_elapsed.inMilliseconds / (estimateSeconds * 1000)).clamp(0.0, 1.0);

  /// 0.0 -> 1.0 against your best time. Fills faster if your best is quick.
  double get ghostProgress {
    if (ghostSeconds == null) return 0;
    return (_elapsed.inMilliseconds / (ghostSeconds! * 1000)).clamp(0.0, 1.0);
  }

  bool get ghostFinished => ghostSeconds != null && ghostProgress >= 1.0;
  bool get overEstimate => _elapsed.inSeconds > estimateSeconds;

  /// Pass [startedAt] to resume a session that began in the past (e.g. one
  /// restored after the app process was killed) instead of starting fresh.
  void start({DateTime? startedAt}) {
    if (isRunning) return;
    _startedAt = startedAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(_startedAt!);
    _crossedEstimate = overEstimate;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _elapsed = DateTime.now().difference(_startedAt!);
      if (!_crossedEstimate && overEstimate) {
        _crossedEstimate = true;
        onCrossEstimate?.call();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  int stop() {
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
    return _elapsed.inSeconds;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}