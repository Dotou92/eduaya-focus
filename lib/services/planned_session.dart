import 'recurrence.dart';

/// Une séance planifiée à l'avance (§9 du cahier des charges,
/// planificateur intelligent).
class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.subject,
    required this.dateTime,
    required this.durationMinutes,
    this.title,
    this.blockedPackages = const {},
    this.blockedAppNames = const [],
    this.recurrence = const RecurrenceRule(),
    this.seriesId,
    this.completed = false,
  });

  final String id;
  final String subject;

  /// Titre libre facultatif (ex: "Révisions chapitre 4").
  final String? title;

  final DateTime dateTime;
  final int durationMinutes;

  /// Noms de packages Android à bloquer pendant cette séance.
  final Set<String> blockedPackages;

  /// Noms affichables correspondant à [blockedPackages] (capturés au
  /// moment de la planification), pour l'historique/les rapports.
  final List<String> blockedAppNames;

  final RecurrenceRule recurrence;

  /// Identifiant commun à toutes les occurrences générées à partir
  /// d'une même séance récurrente (null si séance ponctuelle).
  final String? seriesId;

  /// Marquée comme terminée par l'élève (simple pense-bête ; ne
  /// touche pas à l'historique/aux statistiques, qui ne suivent que
  /// les séances réellement chronométrées).
  final bool completed;

  DateTime get endDateTime => dateTime.add(Duration(minutes: durationMinutes));

  PlannedSession copyWith({
    String? id,
    String? subject,
    String? title,
    bool clearTitle = false,
    DateTime? dateTime,
    int? durationMinutes,
    Set<String>? blockedPackages,
    List<String>? blockedAppNames,
    RecurrenceRule? recurrence,
    String? seriesId,
    bool? completed,
  }) {
    return PlannedSession(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      title: clearTitle ? null : (title ?? this.title),
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      blockedPackages: blockedPackages ?? this.blockedPackages,
      blockedAppNames: blockedAppNames ?? this.blockedAppNames,
      recurrence: recurrence ?? this.recurrence,
      seriesId: seriesId ?? this.seriesId,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'title': title,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes,
        'blockedPackages': blockedPackages.toList(),
        'blockedAppNames': blockedAppNames,
        'recurrence': recurrence.toJson(),
        'seriesId': seriesId,
        'completed': completed,
      };

  factory PlannedSession.fromJson(Map<String, dynamic> json) {
    return PlannedSession(
      id: json['id'] as String,
      subject: json['subject'] as String,
      title: json['title'] as String?,
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dateTime'] as int),
      durationMinutes: json['durationMinutes'] as int,
      blockedPackages: (json['blockedPackages'] as List?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
      blockedAppNames: (json['blockedAppNames'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recurrence: RecurrenceRule.fromJson(
        json['recurrence'] as Map<String, dynamic>?,
      ),
      seriesId: json['seriesId'] as String?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
