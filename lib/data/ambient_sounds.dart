/// Bibliothèque de sons d'ambiance disponibles pendant une session
/// (§4 du cahier des charges). Le cahier des charges prévoyait 8
/// ambiances par catégorie (pluie, bruit blanc, forêt...), mais les 6
/// morceaux réellement fournis sont des musiques instrumentales
/// calmes plutôt que des bruitages nature précis — la liste ci-dessous
/// reflète honnêtement ce qui est disponible dans assets/sounds/.
class AmbientSound {
  const AmbientSound(this.id, this.label, this.assetPath);

  final String id;
  final String label;

  /// Chemin relatif au dossier assets/ (convention audioplayers).
  final String assetPath;
}

const List<AmbientSound> ambientSounds = [
  AmbientSound('mont_blanc', 'Mont Blanc', 'sounds/mont_blanc.mp3'),
  AmbientSound('calme_elegant', 'Calme élégant', 'sounds/calme_elegant.mp3'),
  AmbientSound(
    'calme_inspirant',
    'Calme inspirant',
    'sounds/calme_inspirant.mp3',
  ),
  AmbientSound(
    'merveilles_terre',
    'Merveilles de la Terre',
    'sounds/merveilles_terre.mp3',
  ),
  AmbientSound('royaume_blanc', 'Le Royaume Blanc', 'sounds/royaume_blanc.mp3'),
  AmbientSound('moment_de_paix', 'Moment de paix', 'sounds/moment_de_paix.mp3'),
];
