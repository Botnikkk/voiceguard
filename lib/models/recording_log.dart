enum RecordingVerdict { safe, flagged, escalated }

class RecordingLog {
  final String id;
  final String recordingName;
  final DateTime timestamp;
  final double riskScore; // 0.0 - 1.0
  final RecordingVerdict verdict;
  final Duration duration;

  const RecordingLog({
    required this.id,
    required this.recordingName,
    required this.timestamp,
    required this.riskScore,
    required this.verdict,
    required this.duration,
  });

  /// Dummy data
  static List<RecordingLog> dummyList() {
    final now = DateTime.now();
    return [
      RecordingLog(
        id: 'c1',
        recordingName: 'Demo Recording 1',
        timestamp: now.subtract(const Duration(minutes: 12)),
        riskScore: 0.91,
        verdict: RecordingVerdict.escalated,
        duration: const Duration(minutes: 3, seconds: 42),
      ),
      RecordingLog(
        id: 'c2',
        recordingName: 'Demo Recording 2',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
        riskScore: 0.78,
        verdict: RecordingVerdict.flagged,
        duration: const Duration(minutes: 1, seconds: 15),
      ),
      RecordingLog(
        id: 'c3',
        recordingName: 'Demo Recording 3',
        timestamp: now.subtract(const Duration(hours: 3)),
        riskScore: 0.06,
        verdict: RecordingVerdict.safe,
        duration: const Duration(minutes: 8, seconds: 3),
      ),
    ];
  }
}
