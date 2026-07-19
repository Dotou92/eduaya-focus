import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'planned_session.dart';

/// Rappels locaux pour les séances planifiées (§9 du cahier des
/// charges). Les rappels sont "inexacts" (fenêtre de quelques minutes)
/// pour éviter de demander la permission "alarmes exactes", plus
/// sensible côté revue Google Play — cohérent avec la philosophie
/// d'engagement volontaire du projet (§1).
///
/// Le fuseau horaire est fixé sur celui du Bénin (Africa/Lagos, UTC+1
/// toute l'année, pas de changement d'heure) plutôt que détecté
/// dynamiquement, pour éviter une dépendance supplémentaire.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

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
    );
    await Permission.notification.request();
    _initialized = true;
  }

  static Future<void> scheduleReminder(PlannedSession session) async {
    await init();
    final scheduled = tz.TZDateTime.from(session.dateTime, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }
    await _plugin.zonedSchedule(
      session.id.hashCode,
      "Séance programmée",
      "C'est l'heure de ta séance de ${session.subject} !",
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'eduaya_focus_planning',
          'Rappels de séances',
          channelDescription: 'Rappels pour les séances planifiées',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(String id) async {
    await _plugin.cancel(id.hashCode);
  }
}
