import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';
import '../../../core/network/voice_analysis_socket.dart';
import '../../../core/services/settings_service.dart';
import '../../../models/analysis_result.dart';

class VoiceAnalysisState {
  final bool isSpeaking;
  final double amplitude;
  final AnalysisResult analysis;

  const VoiceAnalysisState({
    this.isSpeaking = false,
    this.amplitude = 0.0,
    this.analysis = const AnalysisResult(),
  });

  VoiceAnalysisState copyWith(
      {bool? isSpeaking, double? amplitude, AnalysisResult? analysis}) {
    return VoiceAnalysisState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      amplitude: amplitude ?? this.amplitude,
      analysis: analysis ?? this.analysis,
    );
  }
}

final voiceAnalysisProvider = StateNotifierProvider.autoDispose<
    VoiceAnalysisNotifier, VoiceAnalysisState>((ref) {
  final socket = VoiceAnalysisSocket(
      'ws://relieving-alone-rewind.ngrok-free.dev/ws/detect');
  return VoiceAnalysisNotifier(socket);
});

class VoiceAnalysisNotifier extends StateNotifier<VoiceAnalysisState> {
  final VoiceAnalysisSocket _socket;
  VadHandler? _vadHandler;
  final List<StreamSubscription> _subscriptions = [];
  bool _isListening = false;

  VoiceAnalysisNotifier(this._socket) : super(const VoiceAnalysisState()) {
    _socket.connect();
    _subscriptions.add(_socket.resultStream.listen((result) {
      state = state.copyWith(analysis: result);
    }));
  }

  Future<void> startListening() async {
    if (_isListening) return;

    _vadHandler = VadHandler.create(isDebug: false);
    _setupVad();

    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final sensitivity = SettingsService.instance.sensitivity.value;
    final positiveThreshold = 0.9 - ((sensitivity / 100) * 0.8);
    final negativeThreshold = (positiveThreshold - 0.15).clamp(0.05, 0.95);

    await _vadHandler!.startListening(
      model: 'v5',
      positiveSpeechThreshold: positiveThreshold,
      negativeSpeechThreshold: negativeThreshold,
      minSpeechFrames: 3,
      redemptionFrames: 20,
    );

    _isListening = true;
  }

  void _setupVad() {
    _subscriptions.add(_vadHandler!.onSpeechStart.listen((_) {
      state = state.copyWith(isSpeaking: true);
    }));

    _subscriptions.add(_vadHandler!.onFrameProcessed.listen((frameData) {
      final frame = frameData.frame;
      if (frame.isEmpty) return;

      double sumSquares = 0.0;
      for (final sample in frame) {
        sumSquares += sample * sample;
      }
      final double rms = math.sqrt(sumSquares / frame.length);

      final double normalized = (rms * 12.0).clamp(0.0, 1.0);

      final double displayAmplitude = state.isSpeaking
          ? normalized
          : (normalized < 0.15 ? 0.05 : normalized);

      state = state.copyWith(amplitude: displayAmplitude);
    }));

    _subscriptions.add(_vadHandler!.onSpeechEnd.listen((samples) {
      state = state.copyWith(isSpeaking: false);

      if (samples.isNotEmpty) {
        _socket.sendAudioChunk(samples);
      }
    }));

    _subscriptions.add(_vadHandler!.onVADMisfire.listen((_) {
      state = state.copyWith(isSpeaking: false);
    }));
  }

  Future<void> stopListening() async {
    if (_isListening && _vadHandler != null) {
      await _vadHandler!.stopListening();
      _isListening = false;
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _vadHandler?.dispose();
    _socket.dispose();
    super.dispose();
  }
}
