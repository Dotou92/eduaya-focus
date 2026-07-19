/// Durées recommandées par type de matière (§2 du cahier des charges).
/// Ce ne sont que des suggestions par défaut, librement modifiables par
/// l'élève au moment de choisir l'heure de fin.
class RecommendedDuration {
  const RecommendedDuration({
    required this.focusMinutes,
    required this.breakMinutes,
  });

  final int focusMinutes;
  final int breakMinutes;
}

enum SubjectCategory { scientific, literary, personalWork }

const Map<SubjectCategory, RecommendedDuration> _categoryDurations = {
  SubjectCategory.scientific: RecommendedDuration(focusMinutes: 50, breakMinutes: 10),
  SubjectCategory.literary: RecommendedDuration(focusMinutes: 45, breakMinutes: 15),
  SubjectCategory.personalWork: RecommendedDuration(focusMinutes: 30, breakMinutes: 5),
};

/// Classement des matières listées dans data/subjects.dart. Le cahier
/// des charges ne donne des exemples que pour 3 matières par
/// catégorie ; le reste est une extrapolation raisonnable (à ajuster
/// si besoin).
const Map<String, SubjectCategory> _subjectCategories = {
  // Scientifiques : 50 min / 10 min de pause
  'Mathématiques': SubjectCategory.scientific,
  'Physique-Chimie': SubjectCategory.scientific,
  'Physique-Chimie-Technologie (PCT)': SubjectCategory.scientific,
  'Sciences de la Vie et de la Terre (SVT)': SubjectCategory.scientific,
  'Informatique': SubjectCategory.scientific,
  'Mathématiques financières': SubjectCategory.scientific,
  'Comptabilité': SubjectCategory.scientific,
  'Technologie / Génie mécanique, électrique ou civil': SubjectCategory.scientific,

  // Langues et littéraires : 45 min / 15 min de pause
  'Français': SubjectCategory.literary,
  'Anglais': SubjectCategory.literary,
  'Espagnol': SubjectCategory.literary,
  'Allemand': SubjectCategory.literary,
  'Philosophie': SubjectCategory.literary,
  'Histoire-Géographie': SubjectCategory.literary,
  'Éducation Civique et Morale (ECM)': SubjectCategory.literary,
  'Éducation Physique et Sportive (EPS)': SubjectCategory.literary,
  'Arts Plastiques / Éducation Artistique': SubjectCategory.literary,
  'Latin': SubjectCategory.literary,
  "Économie / Économie d'entreprise": SubjectCategory.literary,
  'Droit': SubjectCategory.literary,
  'Techniques de secrétariat': SubjectCategory.literary,
  'Techniques commerciales': SubjectCategory.literary,
  'Économie Familiale et Sociale': SubjectCategory.literary,

  // Lecture / travail personnel : 30 min / 5 min de pause
  'Travail personnel / Lecture': SubjectCategory.personalWork,
  "Préparation d'un devoir": SubjectCategory.personalWork,
  "Préparation d'un examen": SubjectCategory.personalWork,
  'Révision BEPC': SubjectCategory.personalWork,
  'Révision BAC': SubjectCategory.personalWork,
};

RecommendedDuration recommendedDurationFor(String subject) {
  final category = _subjectCategories[subject] ?? SubjectCategory.literary;
  return _categoryDurations[category]!;
}
