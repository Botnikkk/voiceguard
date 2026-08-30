enum CallVerdict { safe, flagged, escalated }

class CallLog {
  final String id;
  final String callerName;
  final String callerNumber;
  final DateTime timestamp;
  final double riskScore; // 0.0 - 1.0
  final CallVerdict verdict;
  final Duration duration;

  const CallLog({
    required this.id,
    required this.callerName,
    required this.callerNumber,
    required this.timestamp,
    required this.riskScore,
    required this.verdict,
    required this.duration,
  });

  /// Dummy data
  static List<CallLog> dummyList() {
    final now = DateTime.now();
    return [
      CallLog(
        id: 'c1',
        callerName: 'Rajesh Kumar (Bank Manager)',
        callerNumber: '+91 98XXX 44210',
        timestamp: now.subtract(const Duration(minutes: 12)),
        riskScore: 0.91,
        verdict: CallVerdict.escalated,
        duration: const Duration(minutes: 3, seconds: 42),
      ),
      CallLog(
        id: 'c2',
        callerName: 'Unknown Caller',
        callerNumber: '+91 70XXX 88123',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
        riskScore: 0.78,
        verdict: CallVerdict.flagged,
        duration: const Duration(minutes: 1, seconds: 15),
      ),
      CallLog(
        id: 'c3',
        callerName: 'Mom',
        callerNumber: '+91 99XXX 10432',
        timestamp: now.subtract(const Duration(hours: 3)),
        riskScore: 0.06,
        verdict: CallVerdict.safe,
        duration: const Duration(minutes: 8, seconds: 3),
      ),
      CallLog(
        id: 'c4',
        callerName: 'Amit Singh (Colleague)',
        callerNumber: '+91 98XXX 55219',
        timestamp: now.subtract(const Duration(hours: 5, minutes: 20)),
        riskScore: 0.12,
        verdict: CallVerdict.safe,
        duration: const Duration(minutes: 4, seconds: 51),
      ),
      CallLog(
        id: 'c5',
        callerName: 'HDFC Customer Care',
        callerNumber: '+91 18001234XX',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        riskScore: 0.55,
        verdict: CallVerdict.flagged,
        duration: const Duration(minutes: 2, seconds: 9),
      ),
    ];
  }
}
