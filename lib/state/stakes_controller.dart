import 'package:flutter/foundation.dart';

class StakesOutcome {
  final bool beatEstimate;
  final int coinDelta;
  final int streak;
  final bool protected; // true if a skip-penalty token absorbed a miss

  const StakesOutcome({
    required this.beatEstimate,
    required this.coinDelta,
    required this.streak,
    this.protected = false,
  });
}

class StakesController extends ChangeNotifier {
  static const protectionTokenCost = 100;

  int coins = 50;
  int streak = 0;
  int bestStreak = 0;
  int protectionTokens = 0;

  /// Spends [protectionTokenCost] coins for one skip-penalty token. Returns
  /// false (no-op) if there aren't enough coins.
  bool buyProtectionToken() {
    if (coins < protectionTokenCost) return false;
    coins -= protectionTokenCost;
    protectionTokens++;
    notifyListeners();
    return true;
  }

  StakesOutcome apply({required int estimate, required int actual}) {
    final beat = actual <= estimate;

    if (!beat && protectionTokens > 0) {
      protectionTokens--;
      notifyListeners();
      return StakesOutcome(
        beatEstimate: false,
        coinDelta: 0,
        streak: streak,
        protected: true,
      );
    }

    final delta = beat ? 10 : -15; // losing hurts more than winning pays
    coins = (coins + delta).clamp(0, 99999);

    if (beat) {
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
    }

    notifyListeners();
    return StakesOutcome(beatEstimate: beat, coinDelta: delta, streak: streak);
  }
}