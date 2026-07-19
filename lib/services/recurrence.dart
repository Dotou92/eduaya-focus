/// Règle de récurrence d'une séance planifiée (planificateur intelligent,
/// calendrier §9).
///
/// Choix d'implémentation : plutôt qu'une récurrence "virtuelle" infinie
/// (calculée à la volée, avec toute la complexité de "modifier cette
/// occurrence / toutes les occurrences suivantes / toute la série" que
/// ça implique), une série récurrente génère un nombre fixe
/// d'occurrences concrètes et indépendantes à sa création (horizon de
/// [RecurrenceRule.generationHorizonDays] jours). Chaque occurrence peut
/// ensuite être modifiée, reportée ou supprimée individuellement, comme
/// n'importe quelle séance normale — sans propagation automatique aux
/// autres occurrences de la série.
enum RecurrenceType { none, daily, weekdays, weekly, monthly, custom }

class RecurrenceRule {
  const RecurrenceRule({
    this.type = RecurrenceType.none,
    this.customWeekdays = const {},
  });

  /// Type de récurrence.
  final RecurrenceType type;

  /// Jours de la semaine (1 = lundi ... 7 = dimanche), utilisé
  /// uniquement quand [type] == [RecurrenceType.custom].
  final Set<int> customWeekdays;

  static const int generationHorizonDays = 60;

  bool get isRecurring => type != RecurrenceType.none;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'customWeekdays': customWeekdays.toList(),
      };

  factory RecurrenceRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RecurrenceRule();
    }
    final typeName = json['type'] as String? ?? 'none';
    final type = RecurrenceType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => RecurrenceType.none,
    );
    final weekdays = (json['customWeekdays'] as List?)
            ?.map((e) => e as int)
            .toSet() ??
        <int>{};
    return RecurrenceRule(type: type, customWeekdays: weekdays);
  }

  /// Dates (jour + heure identiques à [firstOccurrence]) sur lesquelles
  /// une occurrence doit être générée, sur l'horizon de génération.
  /// Inclut toujours [firstOccurrence] elle-même en première position.
  List<DateTime> generateOccurrenceDates(DateTime firstOccurrence) {
    if (!isRecurring) {
      return [firstOccurrence];
    }

    final horizon =
        firstOccurrence.add(const Duration(days: generationHorizonDays));
    final dates = <DateTime>[];
    var cursor = firstOccurrence;

    while (!cursor.isAfter(horizon)) {
      final matches = switch (type) {
        RecurrenceType.daily => true,
        RecurrenceType.weekdays => cursor.weekday <= 5,
        RecurrenceType.weekly => cursor.weekday == firstOccurrence.weekday,
        RecurrenceType.monthly => cursor.day == firstOccurrence.day,
        RecurrenceType.custom => customWeekdays.contains(cursor.weekday),
        RecurrenceType.none => false,
      };
      if (matches) {
        dates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return dates;
  }

  String get label {
    switch (type) {
      case RecurrenceType.none:
        return 'Ne se répète pas';
      case RecurrenceType.daily:
        return 'Tous les jours';
      case RecurrenceType.weekdays:
        return 'Tous les jours ouvrables';
      case RecurrenceType.weekly:
        return 'Toutes les semaines';
      case RecurrenceType.monthly:
        return 'Tous les mois';
      case RecurrenceType.custom:
        return 'Personnalisée';
    }
  }
}
