import 'package:flutter/foundation.dart';

class StreakOutcome {
  final bool beatEstimate;
  final int streak;

  const StreakOutcome({required this.beatEstimate, required this.streak});
}

class StreakController extends ChangeNotifier {
  int streak = 0;
  int bestStreak = 0;

  StreakOutcome apply({required int estimate, required int actual}) {
    final beat = actual <= estimate;

    if (beat) {
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
    }

    notifyListeners();
    return StreakOutcome(beatEstimate: beat, streak: streak);
  }
}
