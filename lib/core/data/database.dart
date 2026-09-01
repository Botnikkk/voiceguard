import 'package:hive_flutter/hive_flutter.dart';
import 'package:voiceguard/models/recording_log.dart';

class RecordingLogDatabase {
  final Box<RecordingLog> box = Hive.box<RecordingLog>("RecordingBox");

  void createInitialData() {
    // Only inject data if the box is completely empty
    if (box.isNotEmpty) return;

    final now = DateTime.now();

    final initialData = [
      RecordingLog(
        id: 'c1',
        recordingName: 'Demo Recording 1',
        timestamp: now.subtract(const Duration(minutes: 12)),
        riskScore: 0.91,
        verdict: RecordingVerdict.escalated,
        durationInSeconds: 222,
      ),
      RecordingLog(
        id: 'c2',
        recordingName: 'Demo Recording 2',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
        riskScore: 0.78,
        verdict: RecordingVerdict.flagged,
        durationInSeconds: 75,
      ),
      RecordingLog(
        id: 'c3',
        recordingName: 'Demo Recording 3',
        timestamp: now.subtract(const Duration(hours: 3)),
        riskScore: 0.06,
        verdict: RecordingVerdict.safe,
        durationInSeconds: 483,
      ),
    ];

    // Add directly to Hive. No clearing, no in-memory lists.
    box.addAll(initialData);
  }
}
