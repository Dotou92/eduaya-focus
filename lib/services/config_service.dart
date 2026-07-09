import 'package:flutter/services.dart';

/// Pont entre l'interface Flutter et le code natif Android (Kotlin).
/// Permet de vérifier/ouvrir les réglages d'accessibilité, indispensables
/// au blocage des applications.
class ConfigService {
  static const MethodChannel _channel =
      MethodChannel('com.cabinetlalumiere.eduayofocus/accessibility');

  /// Vérifie si le service d'accessibilité EduAyo Focus est activé
  /// dans les réglages système Android.
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool result =
          await _channel.invokeMethod('isAccessibilityEnabled');
      return result;
    } on PlatformException {
      return false;
    }
  }

  /// Ouvre directement l'écran des réglages d'accessibilité Android
  /// pour que l'utilisateur active le service manuellement.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException {
      // Ignoré : l'utilisateur devra ouvrir les réglages manuellement.
    }
  }
}
