import 'package:shared_preferences/shared_preferences.dart';

import 'challenges.dart';

/// Objectifs personnalisés définis par l'élève (§8 du cahier des charges).
class StudyGoals {
  const StudyGoals({
    required this.hoursPerDay,
    required this.sessionsPerWeek,
    required this.consecutiveDaysNoInterruption,
  });

  final double hoursPerDay;
  final int sessionsPerWeek;
  final int consecutiveDaysNoInterruption;

  static const StudyGoals defaults = StudyGoals(
    hoursPerDay: 2,
    sessionsPerWeek: 5,
    consecutiveDaysNoInterruption: 7,
  );

  StudyGoals copyWith({
    double? hoursPerDay,
    int? sessionsPerWeek,
    int? consecutiveDaysNoInterruption,
  }) {
    return StudyGoals(
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      consecutiveDaysNoInterruption:
          consecutiveDaysNoInterruption ?? this.consecutiveDaysNoInterruption,
    );
  }
}

class GoalsService {
  static const _hoursKey = 'goal_hours_per_day';
  static const _sessionsKey = 'goal_sessions_per_week';
  static const _streakKey = 'goal_consecutive_days';

  static Future<StudyGoals> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StudyGoals(
      hoursPerDay:
          prefs.getDouble(_hoursKey) ?? StudyGoals.defaults.hoursPerDay,
      sessionsPerWeek:
          prefs.getInt(_sessionsKey) ?? StudyGoals.defaults.sessionsPerWeek,
      consecutiveDaysNoInterruption: prefs.getInt(_streakKey) ??
          StudyGoals.defaults.consecutiveDaysNoInterruption,
    );
  }

  static Future<void> save(StudyGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hoursKey, goals.hoursPerDay);
    await prefs.setInt(_sessionsKey, goals.sessionsPerWeek);
    await prefs.setInt(
      _streakKey,
      goals.consecutiveDaysNoInterruption,
    );
  }
}

/// Progression courante vers les objectifs personnalisés.
class GoalProgress {
  const GoalProgress({
    required this.todayHours,
    required this.weekSessions,
    required this.cleanStreakDays,
  });

  final double todayHours;
  final int weekSessions;
  final int cleanStreakDays;

  factory GoalProgress.compute(
    List<Map<String, dynamic>> records, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final weekStart = todayDate.subtract(const Duration(days: 6));

    var todayMillis = 0;
    var weekCount = 0;
    for (final r in records) {
      final startMillis = r['start'] as int;
      final endMillis = r['end'] as int;
      final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
      final startDay = DateTime(start.year, start.month, start.day);

      if (startDay == todayDate) {
        todayMillis += (endMillis - startMillis);
      }
      if (!start.isBefore(weekStart)) {
        weekCount++;
      }
    }

    return GoalProgress(
      todayHours: todayMillis / (1000 * 60 * 60),
      weekSessions: weekCount,
      cleanStreakDays: ChallengeEvaluator.cleanDayStreak(records, now: today),
    );
  }
}
