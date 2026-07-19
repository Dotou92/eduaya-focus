import 'package:audioplayers/audioplayers.dart';

/// Lecture en boucle d'une ambiance sonore, avec volume indépendant du
/// reste de l'application (§4 du cahier des charges).
class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  /// Tente de lire [assetPath] en boucle. Retourne false si le fichier
  /// est introuvable (par ex. pas encore déposé dans assets/sounds/),
  /// pour laisser l'appelant afficher un message plutôt que de planter.
  static Future<bool> play(String assetPath, {double volume = 0.5}) async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);
      await _player.play(AssetSource(assetPath));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setVolume(double volume) => _player.setVolume(volume);

  static Future<void> stop() => _player.stop();
}
