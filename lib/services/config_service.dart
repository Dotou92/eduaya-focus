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
    } on PlatformException {
      // Ignoré.
    }
  }

  /// Récupère la liste des applications installées sur le téléphone.
  /// Retourne une liste de Map avec les clés 'name' et 'packageName'.
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

  /// Démarre le service de premier plan qui garde une notification
  /// visible pendant toute la durée de la session.
  static Future<void> startSession(int minutes) async {
    try {
      await _sessionChannel.invokeMethod('startSession', {'minutes': minutes});
    } on PlatformException {
      // Ignoré.
    }
  }

  static Future<void> stopSession() async {
    try {
      await _sessionChannel.invokeMethod('stopSession');
    } on PlatformException {
      // Ignoré.
    }
  }
}
