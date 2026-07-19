/// Un défi actif (§7 du cahier des charges) : progression courante vers
/// un objectif fixe.
class Challenge {
  const Challenge({
    required this.id,
    required this.label,
    required this.progress,
    required this.target,
    required this.unit,
  });

  final String id;
  final String label;
  final double progress;
  final double target;
  final String unit;

  bool get isCompleted => progress >= target;

  double get progressRatio =>
      target <= 0 ? 0 : (progress / target).clamp(0, 1);
}

class ChallengeEvaluator {
  static List<Challenge> evaluate(
    List<Map<String, dynamic>> records, {
    DateTime? now,
  }) {
    final cleanStreak = cleanDayStreak(records, now: now);
    final totalHours = totalStudyHours(records);

    return [
      Challenge(
        id: '7_jours_sans_interruption',
        label: '7 jours sans interruption',
        progress: cleanStreak.toDouble(),
        target: 7,
        unit: 'jours',
      ),
      Challenge(
        id: '50h_etude_cumulees',
        label: "50h d'étude cumulées",
        progress: totalHours,
        target: 50,
        unit: 'h',
      ),
      Challenge(
        id: '100h_etude_cumulees',
        label: "100h d'étude cumulées",
        progress: totalHours,
        target: 100,
        unit: 'h',
      ),
    ];
  }

  /// Nombre de jours consécutifs (jusqu'à aujourd'hui) ayant eu au moins
  /// une session, et dont toutes les sessions du jour sont sans
  /// interruption. Réutilisé par le module "objectifs personnalisés".
  static int cleanDayStreak(
    List<Map<String, dynamic>> records, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final daysWithSessions = <DateTime>{};
    final dayHasInterruption = <DateTime, bool>{};

    for (final r in records) {
      final start = DateTime.fromMillisecondsSinceEpoch(r['start'] as int);
      final day = DateTime(start.year, start.month, start.day);
      daysWithSessions.add(day);

      final interruptions = (r['interruptions'] as List?)?.length ?? 0;
      if (interruptions > 0) {
        dayHasInterruption[day] = true;
      } else {
        dayHasInterruption.putIfAbsent(day, () => false);
      }
    }

    var cursor = todayDate;
    if (!daysWithSessions.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (daysWithSessions.contains(cursor) &&
        dayHasInterruption[cursor] == false) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Total d'heures d'étude cumulées (toutes sessions confondues).
  static double totalStudyHours(List<Map<String, dynamic>> records) {
    var totalMillis = 0;
    for (final r in records) {
      final start = r['start'] as int;
      final end = r['end'] as int;
      totalMillis += (end - start);
    }
    return totalMillis / (1000 * 60 * 60);
  }
}
