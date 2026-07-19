import 'focus_score.dart';

/// Un badge débloqué (§7 du cahier des charges).
class FocusBadge {
  const FocusBadge(this.id, this.label);

  final String id;
  final String label;
}

class BadgeEvaluator {
  /// Nombre de semaines consécutives à Indice Focus ≥ 90 requis pour
  /// débloquer "Maître de la Discipline".
  static const int masterWeeksRequired = 4;
  static const double masterWeeklyThreshold = 90;

  static List<FocusBadge> evaluate({
    required FocusScore weeklyScore,
    required List<FocusScore> recentWeeklyScores,
    required int totalCompletedSessions,
  }) {
    final badges = <FocusBadge>[];

    if (weeklyScore.overall >= 90) {
      badges.add(const FocusBadge('concentre_or', 'Concentré Or'));
    } else if (weeklyScore.overall >= 70) {
      badges.add(const FocusBadge('concentre_argent', 'Concentré Argent'));
    } else if (weeklyScore.overall >= 50) {
      badges.add(const FocusBadge('concentre_bronze', 'Concentré Bronze'));
    }

    if (recentWeeklyScores.length >= masterWeeksRequired &&
        recentWeeklyScores
            .take(masterWeeksRequired)
            .every((w) => w.overall >= masterWeeklyThreshold)) {
      badges.add(
        const FocusBadge('maitre_discipline', 'Maître de la Discipline'),
      );
    }

    if (totalCompletedSessions >= 100) {
      badges.add(
        const FocusBadge('serie_100_seances', 'Série de 100 séances'),
      );
    }
    if (totalCompletedSessions >= 200) {
      badges.add(const FocusBadge('legende_focus', 'Légende Focus'));
    }

    return badges;
  }
}
