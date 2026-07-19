/// Rapport hebdomadaire autonome (§10 du cahier des charges).
///
/// "Temps gagné" n'est pas mesurable précisément avec les données
/// actuelles (on ne sait pas combien de temps une distraction aurait
/// duré) : on affiche à la place le nombre de fois où l'app a détecté
/// et intercepté une tentative de sortie de session — une mesure
/// honnête plutôt qu'une estimation de temps inventée.
class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.totalHours,
    required this.subjectMinutes,
    required this.concentrationRatePercent,
    required this.distractionsIntercepted,
    required this.mostBlockedApps,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final double totalHours;

  /// Minutes d'étude par matière, triées de la plus étudiée à la
  /// moins étudiée.
  final Map<String, double> subjectMinutes;

  final double concentrationRatePercent;
  final int distractionsIntercepted;

  /// Applications les plus souvent sélectionnées pour être bloquées,
  /// avec le nombre de sessions où elles l'ont été.
  final List<MapEntry<String, int>> mostBlockedApps;

  factory WeeklyReport.compute(
    List<Map<String, dynamic>> records, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final weekStart = todayDate.subtract(const Duration(days: 6));
    final weekEnd = todayDate.add(const Duration(days: 1));

    final weekRecords = records.where((r) {
      final start =
          DateTime.fromMillisecondsSinceEpoch(r['start'] as int);
      return !start.isBefore(weekStart) && start.isBefore(weekEnd);
    }).toList();

    var totalMillis = 0;
    final subjectMillis = <String, int>{};
    var interruptedFreeSessions = 0;
    var distractions = 0;
    final appCounts = <String, int>{};

    for (final r in weekRecords) {
      final startMillis = r['start'] as int;
      final endMillis = r['end'] as int;
      final duration = endMillis - startMillis;
      totalMillis += duration;

      final subject = (r['subject'] as String?) ?? 'Non précisé';
      subjectMillis[subject] = (subjectMillis[subject] ?? 0) + duration;

      final interruptions = (r['interruptions'] as List?) ?? const [];
      if (interruptions.isEmpty) {
        interruptedFreeSessions++;
      }
      distractions += interruptions.length;

      final apps = (r['appNames'] as List?) ?? const [];
      for (final app in apps) {
        final name = app as String;
        appCounts[name] = (appCounts[name] ?? 0) + 1;
      }
    }

    final subjectMinutes = {
      for (final entry in subjectMillis.entries)
        entry.key: entry.value / (1000 * 60),
    };

    final mostBlocked = appCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final concentrationRate = weekRecords.isEmpty
        ? 0.0
        : (interruptedFreeSessions / weekRecords.length) * 100;

    return WeeklyReport(
      weekStart: weekStart,
      weekEnd: todayDate,
      totalHours: totalMillis / (1000 * 60 * 60),
      subjectMinutes: subjectMinutes,
      concentrationRatePercent: concentrationRate,
      distractionsIntercepted: distractions,
      mostBlockedApps: mostBlocked.take(5).toList(),
    );
  }
}
