import 'focus_score.dart';

/// Un badge débloqué (§7 du cahier des charges). Seuls les badges dont
/// le seuil est déductible des critères déjà définis (Indice Focus,
/// nombre de séances) sont implémentés pour l'instant ; "Légende Focus"
/// et "Maître de la Discipline" nécessitent des seuils à définir avec
/// le porteur de projet avant d'être ajoutés.
class FocusBadge {
  const FocusBadge(this.id, this.label);

  final String id;
  final String label;
}

class BadgeEvaluator {
  static List<FocusBadge> evaluate({
    required FocusScore weeklyScore,
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

    if (totalCompletedSessions >= 100) {
      badges.add(
        const FocusBadge('serie_100_seances', 'Série de 100 séances'),
      );
    }

    return badges;
  }
}
