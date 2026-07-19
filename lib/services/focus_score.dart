/// Indice Focus hebdomadaire : moyenne pondérée de trois critères
/// (§6 du cahier des charges). Pondération par défaut :
/// 40% concentration / 30% régularité / 30% persévérance.
///
/// Le modèle de données actuel ne conserve pas la durée exacte perdue
/// pendant chaque interruption (seulement l'instant où elle a été
/// détectée), donc la concentration est approximée par une pénalité
/// fixe par interruption plutôt que par un calcul de durée exacte.
class FocusScore {
  const FocusScore({
    required this.concentration,
    required this.regularity,
    required this.perseverance,
    required this.overall,
  });

  final double concentration;
  final double regularity;
  final double perseverance;
  final double overall;

  static const double concentrationWeight = 0.4;
  static const double regularityWeight = 0.3;
  static const double perseveranceWeight = 0.3;
  static const int interruptionPenaltyPercent = 20;

  factory FocusScore.compute(
    List<Map<String, dynamic>> records, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final weekStart = todayDate.subtract(const Duration(days: 6));

    final weekRecords = records.where((r) {
      final start = DateTime.fromMillisecondsSinceEpoch(r['start'] as int);
      return !start.isBefore(weekStart);
    }).toList();

    final concentration = _computeConcentration(weekRecords);
    final regularity = _computeRegularity(records, todayDate);
    final perseverance = _computePerseverance(weekRecords);

    final overall = (concentration * concentrationWeight) +
        (regularity * regularityWeight) +
        (perseverance * perseveranceWeight);

    return FocusScore(
      concentration: concentration,
      regularity: regularity,
      perseverance: perseverance,
      overall: overall,
    );
  }

  static double _computeConcentration(List<Map<String, dynamic>> weekRecords) {
    if (weekRecords.isEmpty) {
      return 0;
    }
    var total = 0.0;
    for (final r in weekRecords) {
      final interruptions = (r['interruptions'] as List?)?.length ?? 0;
      final score =
          (100 - interruptions * interruptionPenaltyPercent).clamp(0, 100);
      total += score;
    }
    return total / weekRecords.length;
  }

  static double _computeRegularity(
    List<Map<String, dynamic>> records,
    DateTime todayDate,
  ) {
    final days = <DateTime>{};
    for (final r in records) {
      final start = DateTime.fromMillisecondsSinceEpoch(r['start'] as int);
      days.add(DateTime(start.year, start.month, start.day));
    }

    var cursor = todayDate;
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (streak.clamp(0, 7) / 7) * 100;
  }

  static double _computePerseverance(List<Map<String, dynamic>> weekRecords) {
    if (weekRecords.isEmpty) {
      return 0;
    }
    final completed = weekRecords.where((r) => r['completed'] == true).length;
    return (completed / weekRecords.length) * 100;
  }
}
