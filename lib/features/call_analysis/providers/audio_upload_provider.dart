import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/voice_analysis_socket.dart';
import '../../../core/utils/wav_decoder.dart';
import '../../../core/utils/mp3_decoder.dart';
import '../../../models/analysis_result.dart';

enum UploadStage { idle, decoding, streaming, awaitingVerdict, done, error }

class AudioUploadState {
  final UploadStage stage;
  final String? fileName;
  final double progress; // 0..1 of samples streamed so far
  final AnalysisResult analysis;
  final String? errorMessage;

  const AudioUploadState({
    this.stage = UploadStage.idle,
    this.fileName,
    this.progress = 0.0,
    this.analysis = const AnalysisResult(),
    this.errorMessage,
  });

  AudioUploadState copyWith({
    UploadStage? stage,
    String? fileName,
    double? progress,
    AnalysisResult? analysis,
    String? errorMessage,
  }) {
    return AudioUploadState(
      stage: stage ?? this.stage,
      fileName: fileName ?? this.fileName,
      progress: progress ?? this.progress,
      analysis: analysis ?? this.analysis,
      errorMessage: errorMessage,
    );
  }
}

final audioUploadProvider =
    StateNotifierProvider.autoDispose<AudioUploadNotifier, AudioUploadState>(
        (ref) {
  final socket = VoiceAnalysisSocket(ApiConfig.voiceAnalysisWsUrl);
  return AudioUploadNotifier(socket);
});

class AudioUploadNotifier extends StateNotifier<AudioUploadState> {
  final VoiceAnalysisSocket _socket;
  StreamSubscription<AnalysisResult>? _resultSub;
  bool _disposed = false;

  int _totalSamples = 0;

  int _lastConfirmedSamples = 0;

  static const int _chunkSize = 512 * 64;
  static const Duration _interChunkDelay = Duration.zero;

  static const int _serverWindowSamples = 64600;
  static const int _serverStepSamples = 24000;
  static const int _leadWindowMultiplier = 2;
  static const int _maxLeadSamples =
      (_serverWindowSamples + _serverStepSamples) * _leadWindowMultiplier;
  static const Duration _backpressurePoll = Duration(milliseconds: 40);
  static const Duration _maxBackpressureWaitPerChunk = Duration(seconds: 8);

  AudioUploadNotifier(this._socket) : super(const AudioUploadState()) {
    _socket.connect();
    _resultSub = _socket.resultStream.listen((result) {
      if (_disposed) return;

      final analyzedFraction = _totalSamples > 0
          ? (result.samplesProcessed / _totalSamples).clamp(0.0, 1.0)
          : state.progress;

      if (result.samplesProcessed > _lastConfirmedSamples) {
        _lastConfirmedSamples = result.samplesProcessed;
      }

      final wasActive = state.stage == UploadStage.streaming ||
          state.stage == UploadStage.decoding ||
          state.stage == UploadStage.awaitingVerdict;

      final nextStage = result.isFinal
          ? UploadStage.done
          : (wasActive ? UploadStage.streaming : state.stage);

      state = state.copyWith(
        analysis: result,
        stage: nextStage,
        progress: result.isFinal ? 1.0 : analyzedFraction,
      );
    });
  }

  Future<void> analyzeFile(String fileName, Uint8List bytes) async {
    state = AudioUploadState(stage: UploadStage.decoding, fileName: fileName);

    late final DecodedAudio decoded;
    try {
      final isMp3 = fileName.toLowerCase().endsWith('.mp3');

      if (isMp3) {
        decoded = await Mp3Decoder.decode(bytes);
      } else {
        decoded = WavDecoder.decode(bytes);
      }
    } on WavDecodeException catch (e) {
      state = state.copyWith(stage: UploadStage.error, errorMessage: e.message);
      return;
    } catch (e) {
      state = state.copyWith(
          stage: UploadStage.error,
          errorMessage: 'Could not read or process this audio file.');
      return;
    }

    if (_disposed) return;
    final samples = decoded.samples;
    final total = samples.length;
    if (total == 0) {
      state = state.copyWith(
          stage: UploadStage.error, errorMessage: 'Audio file is empty.');
      return;
    }
    _totalSamples = total;
    _lastConfirmedSamples = 0;

    state = state.copyWith(stage: UploadStage.streaming, progress: 0.0);

    for (int i = 0; i < total; i += _chunkSize) {
      if (_disposed) return;
      final end = (i + _chunkSize).clamp(0, total);
      _socket.sendAudioChunk(samples.sublist(i, end));

      final sentSoFar = end;
      final backpressureStopwatch = Stopwatch()..start();
      while (!_disposed &&
          (sentSoFar - _lastConfirmedSamples) > _maxLeadSamples &&
          backpressureStopwatch.elapsed < _maxBackpressureWaitPerChunk) {
        await Future.delayed(_backpressurePoll);
      }

      await Future.delayed(_interChunkDelay);
    }

    if (_disposed) return;
    _socket.sendEndSignal();
    if (state.stage != UploadStage.done) {
      state = state.copyWith(stage: UploadStage.awaitingVerdict);
    }

    const maxWait = Duration(seconds: 15);
    const pollInterval = Duration(milliseconds: 150);
    final waitStopwatch = Stopwatch()..start();
    while (!_disposed &&
        waitStopwatch.elapsed < maxWait &&
        state.stage != UploadStage.done) {
      await Future.delayed(pollInterval);
    }

    if (!_disposed && state.stage != UploadStage.done) {
      state = state.copyWith(stage: UploadStage.done, progress: 1.0);
    }
  }

  void reset() {
    _lastConfirmedSamples = 0;
    if (!_disposed) state = const AudioUploadState();
  }

  @override
  void dispose() {
    _disposed = true;
    _resultSub?.cancel();
    _socket.dispose();
    super.dispose();
  }
}
