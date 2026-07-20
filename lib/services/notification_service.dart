import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'planned_session.dart';

/// Rappels locaux pour les séances planifiées (§9 du cahier des
/// charges, planificateur intelligent). Les rappels sont "inexacts"
/// (fenêtre de quelques minutes) pour éviter de demander la permission
/// "alarmes exactes", plus sensible côté revue Google Play — cohérent
/// avec la philosophie d'engagement volontaire du projet (§1).
///
/// Le fuseau horaire est fixé sur celui du Bénin (Africa/Lagos, UTC+1
/// toute l'année, pas de changement d'heure) plutôt que détecté
/// dynamiquement, pour éviter une dépendance supplémentaire.
///
/// Limite assumée : le bouton d'action "Démarrer maintenant" ne
/// fonctionne de façon fiable que si l'app tourne déjà (premier ou
/// arrière-plan) — on ne branche pas de handler d'arrière-plan
/// (isolate séparé) car nos canaux natifs (ConfigService) et la
/// navigation ne sont pas accessibles depuis cet isolate. Si l'app est
/// totalement fermée, taper la notification relance l'app et on
/// détecte ce lancement via [getLaunchDetails] au démarrage.
class NotificationInfo {
  const NotificationInfo({required this.payload, required this.actionId});
  final String? payload;
  final String? actionId;
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Appelé quand l'utilisateur tape une notification ou une de ses
  /// actions, pendant que l'app tourne. Renseigné par main.dart.
  static void Function(NotificationInfo info)? onResponse;

  static const String startNowActionId = 'start_now';
  static const int _repeatCount = 6;
  static const int _repeatIntervalMinutes = 5;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        onResponse?.call(
          NotificationInfo(
            payload: response.payload,
            actionId: response.actionId,
          ),
        );
      },
    );
    await Permission.notification.request();
    _initialized = true;
  }

  /// À vérifier avant de compter sur un rappel : si l'utilisateur a
  /// refusé la permission (ou si l'OS l'a redemandée puis rejetée), les
  /// notifications programmées ne s'affichent jamais, sans aucune
  /// erreur côté code — la seule façon de le savoir est de vérifier ce
  /// statut explicitement.
  static Future<bool> hasPermission() async {
    await init();
    return await Permission.notification.isGranted;
  }

  /// Redemande la permission si elle n'a pas encore été refusée
  /// définitivement. Retourne true si accordée après la demande.
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Renseigné si l'app a été lancée en tapant une notification
  /// (app totalement fermée avant le tap).
  static Future<NotificationInfo?> getLaunchDetails() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    final response = details.notificationResponse;
    if (response == null) {
      return null;
    }
    return NotificationInfo(
      payload: response.payload,
      actionId: response.actionId,
    );
  }

  /// Planifie tous les rappels pour [session] : avant l'heure prévue
  /// (30/10/5 min, chacun optionnel), une notification à l'heure
  /// exacte avec le bouton "Démarrer maintenant", puis des relances
  /// toutes les [_repeatIntervalMinutes] minutes tant que la séance
  /// n'a pas été démarrée (annulées par [cancelAllForSession] dès que
  /// c'est le cas).
  static Future<void> scheduleSessionReminders(
    PlannedSession session, {
    bool remind30 = false,
    bool remind10 = true,
    bool remind5 = true,
  }) async {
    await init();
    await cancelAllForSession(session.id);

    final payload = jsonEncode(session.toJson());
    final titleSubject = session.title?.isNotEmpty == true
        ? "${session.title} (${session.subject})"
        : session.subject;

    Future<void> scheduleAt(
      int slot,
      DateTime when,
      String body, {
      bool withStartAction = false,
    }) async {
      final scheduled = tz.TZDateTime.from(when, tz.local);
      if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        return;
      }
      await _plugin.zonedSchedule(
        _notificationId(session.id, slot),
        titleSubject,
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'eduaya_focus_planning',
            'Rappels de séances',
            channelDescription: 'Rappels pour les séances planifiées',
            importance: Importance.high,
            priority: Priority.high,
            actions: withStartAction
                ? const [
                    AndroidNotificationAction(
                      startNowActionId,
                      'Démarrer maintenant',
                      showsUserInterface: true,
                    ),
                  ]
                : null,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }

    if (remind30) {
      await scheduleAt(
        0,
        session.dateTime.subtract(const Duration(minutes: 30)),
        "Dans 30 minutes.",
      );
    }
    if (remind10) {
      await scheduleAt(
        1,
        session.dateTime.subtract(const Duration(minutes: 10)),
        "Dans 10 minutes.",
      );
    }
    if (remind5) {
      await scheduleAt(
        2,
        session.dateTime.subtract(const Duration(minutes: 5)),
        "Dans 5 minutes.",
      );
    }

    await scheduleAt(
      3,
      session.dateTime,
      "C'est l'heure !",
      withStartAction: true,
    );

    for (var i = 0; i < _repeatCount; i++) {
      await scheduleAt(
        4 + i,
        session.dateTime
            .add(Duration(minutes: _repeatIntervalMinutes * (i + 1))),
        "Toujours partant pour ta séance ?",
        withStartAction: true,
      );
    }
  }

  /// Annule tous les rappels (paliers + relances) d'une séance. À
  /// appeler dès que la séance est démarrée, reportée, modifiée ou
  /// supprimée.
  static Future<void> cancelAllForSession(String sessionId) async {
    for (var slot = 0; slot < 4 + _repeatCount; slot++) {
      await _plugin.cancel(_notificationId(sessionId, slot));
    }
  }

  static int _notificationId(String sessionId, int slot) {
    return (Object.hash(sessionId, slot)) & 0x7FFFFFFF;
  }
}
