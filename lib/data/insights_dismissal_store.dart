import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when a category's weekly insight card was last swiped away.
/// Dismissal only hides the card — it never touches task or run data — and
/// the category reappears on its own once a run more recent than the
/// dismissal comes in.
class InsightsDismissalStore {
  static const _prefsKey = 'task_race.insights.dismissed_categories';

  static Future<Map<String, DateTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, DateTime.parse(value as String)),
    );
  }

  static Future<void> dismiss(String category) async {
    final dismissed = await load();
    dismissed[category] = DateTime.now();
    await _save(dismissed);
  }

  static Future<void> undismiss(String category) async {
    final dismissed = await load();
    dismissed.remove(category);
    await _save(dismissed);
  }

  static Future<void> _save(Map<String, DateTime> dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      dismissed.map((key, value) => MapEntry(key, value.toIso8601String())),
    );
    await prefs.setString(_prefsKey, encoded);
  }
}
