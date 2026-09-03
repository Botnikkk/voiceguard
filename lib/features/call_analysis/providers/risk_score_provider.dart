import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_analysis_provider.dart';

final riskScoreProvider = Provider.autoDispose<double>((ref) {
  final analysis = ref.watch(voiceAnalysisProvider).analysis;
  return analysis.riskScore;
});
