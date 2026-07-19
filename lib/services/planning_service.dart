import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'planned_session.dart';

/// Stockage local des séances planifiées (§9 du cahier des charges).
class PlanningService {
  static const _key = 'planned_sessions';

  static Future<List<PlannedSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final sessions = raw
        .map((s) =>
            PlannedSession.fromJson(Map<String, dynamic>.from(jsonDecode(s))))
        .toList();
    sessions.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return sessions;
  }

  static Future<void> _persist(List<PlannedSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  static Future<void> add(PlannedSession session) async {
    final sessions = await load();
    sessions.add(session);
    await _persist(sessions);
    await NotificationService.scheduleReminder(session);
  }

  static Future<void> remove(String id) async {
    final sessions = await load();
    sessions.removeWhere((s) => s.id == id);
    await _persist(sessions);
    await NotificationService.cancelReminder(id);
  }
}
