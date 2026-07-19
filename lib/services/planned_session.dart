/// Une séance planifiée à l'avance (§9 du cahier des charges).
class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.subject,
    required this.dateTime,
    required this.durationMinutes,
  });

  final String id;
  final String subject;
  final DateTime dateTime;
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes,
      };

  factory PlannedSession.fromJson(Map<String, dynamic> json) {
    return PlannedSession(
      id: json['id'] as String,
      subject: json['subject'] as String,
      dateTime: DateTime.fromMillisecondsSinceEpoch(json['dateTime'] as int),
      durationMinutes: json['durationMinutes'] as int,
    );
  }
}
