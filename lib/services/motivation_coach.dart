/// Coach de motivation à règles simples (§5 du cahier des charges) :
/// des messages déclenchés par des seuils temporels et contextuels,
/// sans aucune dépendance à un modèle d'IA.
enum CoachTrigger { halfway, fifteenMinutesLeft, newRecord }

class MotivationCoach {
  static const Map<CoachTrigger, String> messages = {
    CoachTrigger.halfway: "Tu es à mi-parcours, continue !",
    CoachTrigger.fifteenMinutesLeft: "Plus que 15 minutes, tu y es presque.",
    CoachTrigger.newRecord: "Nouveau record de concentration !",
  };

  /// Retourne le déclencheur à activer à cet instant, ou null si aucun
  /// (déjà déclenché cette session, ou seuil pas encore atteint).
  static CoachTrigger? checkTriggers({
    required DateTime start,
    required DateTime end,
    required DateTime now,
    required bool hasInterruptionThisSession,
    required int? personalBestMinutes,
    required Set<CoachTrigger> alreadyTriggered,
  }) {
    final totalMinutes = end.difference(start).inMinutes;
    final elapsedMinutes = now.difference(start).inMinutes;
    final remainingMinutes = end.difference(now).inMinutes;

    if (!alreadyTriggered.contains(CoachTrigger.newRecord) &&
        !hasInterruptionThisSession &&
        personalBestMinutes != null &&
        personalBestMinutes > 0 &&
        elapsedMinutes > personalBestMinutes) {
      return CoachTrigger.newRecord;
    }

    if (!alreadyTriggered.contains(CoachTrigger.halfway) &&
        totalMinutes >= 2 &&
        elapsedMinutes >= totalMinutes / 2) {
      return CoachTrigger.halfway;
    }

    if (!alreadyTriggered.contains(CoachTrigger.fifteenMinutesLeft) &&
        totalMinutes > 15 &&
        remainingMinutes <= 15 &&
        remainingMinutes >= 0) {
      return CoachTrigger.fifteenMinutesLeft;
    }

    return null;
  }

  /// Durée (en minutes) de la plus longue session déjà réussie sans
  /// aucune interruption, utilisée comme référence pour "newRecord".
  static int? personalBestMinutes(List<Map<String, dynamic>> records) {
    int? best;
    for (final r in records) {
      if (r['completed'] != true) {
        continue;
      }
      final interruptions = (r['interruptions'] as List?) ?? const [];
      if (interruptions.isNotEmpty) {
        continue;
      }
      final start = r['start'] as int;
      final end = r['end'] as int;
      final minutes = ((end - start) / 60000).round();
      if (best == null || minutes > best) {
        best = minutes;
      }
    }
    return best;
  }
}
