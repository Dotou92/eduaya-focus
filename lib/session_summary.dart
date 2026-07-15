class SessionStats {
  const SessionStats({
    required this.totalSessions,
    required this.completedSessions,
    required this.interruptedSessions,
  });

  final int totalSessions;
  final int completedSessions;
  final int interruptedSessions;

  double get completionRatePercent {
    if (totalSessions == 0) {
      return 0;
    }
    return (completedSessions / totalSessions) * 100;
  }

  factory SessionStats.fromRecords(List<Map<String, dynamic>> records) {
    final completed = records.where((r) => r['completed'] == true).length;
    final interrupted = records.where((r) {
      final interruptions = r['interruptions'];
      return interruptions is List && interruptions.isNotEmpty;
    }).length;

    return SessionStats(
      totalSessions: records.length,
      completedSessions: completed,
      interruptedSessions: interrupted,
    );
  }
}
