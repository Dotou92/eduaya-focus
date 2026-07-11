import 'package:flutter/services.dart';

class ConfigService {
  static const MethodChannel _accessibilityChannel =
      MethodChannel('com.cabinetlalumiere.eduayofocus/accessibility');
  static const MethodChannel _sessionChannel =
      MethodChannel('com.cabinetlalumiere.eduayofocus/session');

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool result =
          await _accessibilityChannel.invokeMethod('isAccessibilityEnabled');
      return result;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _accessibilityChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException {}
  }

  static Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic> result =
          await _accessibilityChannel.invokeMethod('getInstalledApps');
      return result
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
    } on PlatformException {
      return [];
    }
  }

  static Future<void> startSession(int endHour, int endMinute) async {
    try {
      await _sessionChannel.invokeMethod('startSession', {
        'endHour': endHour,
        'endMinute': endMinute,
      });
    } on PlatformException {}
  }

  static Future<void> stopSession() async {
    try {
      await _sessionChannel.invokeMethod('stopSession');
    } on PlatformException {}
  }

  /// Retourne l'état réel de la session côté natif : actif, heure de
  /// début, heure de fin, dernier "battement" enregistré. Utile pour
  /// détecter une interruption (app gelée/tuée) au retour dans l'app.
  static Future<Map<String, dynamic>> getSessionStatus() async {
    try {
      final result = await _sessionChannel.invokeMethod('getSessionStatus');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException {
      return {'active': false, 'startTime': 0, 'endTime': 0, 'lastHeartbeat': 0};
    }
  }
}
