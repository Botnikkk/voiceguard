import 'package:hive_flutter/hive_flutter.dart';
part 'recording_log.g.dart';

@HiveType(typeId: 0)
enum RecordingVerdict {
  @HiveField(0)
  safe,
  @HiveField(1)
  flagged,
  @HiveField(2)
  escalated,
}

@HiveType(typeId: 1)
class RecordingLog {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String recordingName;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final double riskScore;

  @HiveField(4)
  final RecordingVerdict verdict;

  // CHANGED: Store duration as an integer representing seconds
  @HiveField(5)
  final int durationInSeconds;

  RecordingLog({
    required this.id,
    required this.recordingName,
    required this.timestamp,
    required this.riskScore,
    required this.verdict,
    required this.durationInSeconds, // Updated here
  });

  // ADDED: This makes sure your UI (log_screen and live_call_screen)
  // doesn't break, because they are still looking for `.duration`
  Duration get duration => Duration(seconds: durationInSeconds);
}
