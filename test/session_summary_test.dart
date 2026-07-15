import 'package:flutter_test/flutter_test.dart';
import 'package:eduayo_focus/services/session_summary.dart';

void main() {
  group('SessionStats', () {
    test('compte les sessions complètes et les interruptions', () {
      final records = [
        {
          'completed': true,
          'interruptions': [1]
        },
        {'completed': false, 'interruptions': []},
        {'completed': true, 'interruptions': []},
      ];

      final stats = SessionStats.fromRecords(records);

      expect(stats.totalSessions, 3);
      expect(stats.completedSessions, 2);
      expect(stats.interruptedSessions, 1);
      expect(stats.completionRatePercent, closeTo(66.67, 0.01));
    });
  });
}
