import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'planned_session.dart';

/// Stockage local et CRUD des séances planifiées (§9 du cahier des
/// charges, planificateur intelligent).
class PlanningService {
  static const _key = 'planned_sessions';
  static final Random _random = Random();

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

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

  /// Ajoute une séance. Si elle est récurrente, génère toutes les
  /// occurrences concrètes de la série (voir recurrence.dart) au lieu
  /// d'une seule entrée.
  static Future<List<PlannedSession>> add(PlannedSession template) async {
    final sessions = await load();
    final created = <PlannedSession>[];

    if (!template.recurrence.isRecurring) {
      created.add(template);
    } else {
      final seriesId = _newId();
      final dates = template.recurrence.generateOccurrenceDates(
        template.dateTime,
      );
      for (final date in dates) {
        created.add(template.copyWith(
          id: date == template.dateTime ? template.id : _newId(),
          dateTime: date,
          seriesId: seriesId,
        ));
      }
    }

    sessions.addAll(created);
    await _persist(sessions);
    for (final session in created) {
      await NotificationService.scheduleSessionReminders(session);
    }
    return created;
  }

  static Future<void> update(PlannedSession updated) async {
    final sessions = await load();
    final index = sessions.indexWhere((s) => s.id == updated.id);
    if (index == -1) {
      return;
    }
    sessions[index] = updated;
    await _persist(sessions);
    await NotificationService.cancelAllForSession(updated.id);
    if (!updated.completed) {
      await NotificationService.scheduleSessionReminders(updated);
    }
  }

  static Future<void> remove(String id) async {
    final sessions = await load();
    sessions.removeWhere((s) => s.id == id);
    await _persist(sessions);
    await NotificationService.cancelAllForSession(id);
  }

  /// Supprime toutes les occurrences futures d'une même série
  /// récurrente (à partir d'aujourd'hui inclus).
  static Future<void> removeSeries(String seriesId) async {
    final sessions = await load();
    final now = DateTime.now();
    final toRemove = sessions
        .where((s) => s.seriesId == seriesId && !s.dateTime.isBefore(now))
        .toList();
    sessions.removeWhere(
      (s) => s.seriesId == seriesId && !s.dateTime.isBefore(now),
    );
    await _persist(sessions);
    for (final s in toRemove) {
      await NotificationService.cancelAllForSession(s.id);
    }
  }

  static Future<PlannedSession> postpone(
    PlannedSession session,
    DateTime newDateTime,
  ) async {
    final updated = session.copyWith(dateTime: newDateTime);
    await update(updated);
    return updated;
  }

  static Future<PlannedSession> duplicate(PlannedSession session) async {
    final copy = session.copyWith(
      id: _newId(),
      dateTime: session.dateTime.add(const Duration(days: 1)),
      seriesId: null,
      completed: false,
    );
    final sessions = await load();
    sessions.add(copy);
    await _persist(sessions);
    await NotificationService.scheduleSessionReminders(copy);
    return copy;
  }

  static Future<void> toggleCompleted(PlannedSession session) async {
    final updated = session.copyWith(completed: !session.completed);
    final sessions = await load();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) {
      return;
    }
    sessions[index] = updated;
    await _persist(sessions);
    // Une séance marquée terminée n'a plus besoin de rappels ; on les
    // annule mais on ne les reprogramme pas si on la décoche (elle est
    // sans doute passée).
    await NotificationService.cancelAllForSession(session.id);
  }

  /// À appeler dès qu'une séance planifiée est réellement démarrée
  /// (bouton "Démarrer maintenant" ou démarrage manuel) pour couper
  /// les relances restantes.
  static Future<void> markStarted(String plannedSessionId) async {
    await NotificationService.cancelAllForSession(plannedSessionId);
  }
}
