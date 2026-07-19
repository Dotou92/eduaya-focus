/// Bibliothèque de sons d'ambiance disponibles pendant une session
/// (§4 du cahier des charges). Les fichiers audio réels doivent être
/// déposés dans assets/sounds/ (voir assets/sounds/README.md) — ils ne
/// sont pas fournis avec le code.
class AmbientSound {
  const AmbientSound(this.id, this.label, this.assetPath);

  final String id;
  final String label;

  /// Chemin relatif au dossier assets/ (convention audioplayers).
  final String assetPath;
}

const List<AmbientSound> ambientSounds = [
  AmbientSound('pluie', 'Pluie', 'sounds/pluie.mp3'),
  AmbientSound('bruit_blanc', 'Bruit blanc', 'sounds/bruit_blanc.mp3'),
  AmbientSound('foret', 'Forêt', 'sounds/foret.mp3'),
  AmbientSound('riviere', 'Rivière', 'sounds/riviere.mp3'),
  AmbientSound('vent', 'Vent', 'sounds/vent.mp3'),
  AmbientSound(
    'musique_instrumentale',
    'Musique instrumentale',
    'sounds/musique_instrumentale.mp3',
  ),
  AmbientSound('bibliotheque', 'Ambiance bibliothèque', 'sounds/bibliotheque.mp3'),
  AmbientSound('cafe_etude', "Ambiance café d'étude", 'sounds/cafe_etude.mp3'),
];
