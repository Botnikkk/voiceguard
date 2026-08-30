import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simulates a real-time AI risk-score stream for the active call.
/// In production this would be fed by the voice-cloning detection model
/// (e.g. spectral/prosody analysis results streamed over a socket).
class RiskScoreController extends StateNotifier<double> {
  Timer? _timer;
  final Random _random = Random();
  int _tick = 0;

  RiskScoreController() : super(0.05) {
    _start();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      _tick++;
      // Demo trajectory: starts low, then escalates to simulate a
      // detected voice-cloning attack partway through the call.
      double target;
      if (_tick < 4) {
        target = 0.05 + _random.nextDouble() * 0.15;
      } else if (_tick < 9) {
        target = 0.35 + _random.nextDouble() * 0.25;
      } else {
        target = 0.75 + _random.nextDouble() * 0.22;
      }
      state = target.clamp(0.0, 1.0);
    });
  }

  void reset() {
    _tick = 0;
    state = 0.05;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final riskScoreProvider = StateNotifierProvider.autoDispose<RiskScoreController, double>(
  (ref) => RiskScoreController(),
);
