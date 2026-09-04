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

  // Total sample count for the file currently being analyzed. Used to turn
  // the server's cumulative "samples_processed" into a 0..1 fraction, so
  // progress reflects audio that has actually been analyzed and returned —
  // not audio that has merely been sent over the socket.
  int _totalSamples = 0;

  // The backend only counts samples, never wall-clock time, so there's no
  // benefit to pacing chunks to real playback speed — send as fast as the
  // socket will take them. A tiny delay just keeps us from queuing the
  // entire buffer synchronously in one microtask burst.
  static const int _chunkSize = 512 * 16;
  static const Duration _interChunkDelay = Duration(milliseconds: 5);

  AudioUploadNotifier(this._socket) : super(const AudioUploadState()) {
    _socket.connect();
    _resultSub = _socket.resultStream.listen((result) {
      if (_disposed) return;
      debugPrintResult(
          result); // see note below — remove once confirmed working

      // Progress is driven ONLY by what the server confirms it has analyzed,
      // never by how much we've sent. This is what keeps the % bar, the
      // gauge, and the verdict all pointing at the same slice of audio.
      final analyzedFraction = _totalSamples > 0
          ? (result.samplesProcessed / _totalSamples).clamp(0.0, 1.0)
          : state.progress;

      final wasActive = state.stage == UploadStage.streaming ||
          state.stage == UploadStage.decoding ||
          state.stage == UploadStage.awaitingVerdict;

      // A result flagged final is the true end of analysis — flip to `done`
      // right away instead of waiting on the blind timeout fallback below.
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

  void debugPrintResult(AnalysisResult r) {
    // ignore: avoid_print
    print('[upload] got result: score=${r.smoothedScore} verdict=${r.verdict} '
        'confidence=${r.confidence}');
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

    state = state.copyWith(stage: UploadStage.streaming, progress: 0.0);

    // NOTE: this loop only paces how fast bytes go over the wire. It
    // deliberately does NOT touch `state.progress` anymore — the % bar,
    // gauge and verdict are all updated together from the result listener
    // above, driven by what the server confirms it has actually analyzed.
    for (int i = 0; i < total; i += _chunkSize) {
      if (_disposed) return;
      final end = (i + _chunkSize).clamp(0, total);
      _socket.sendAudioChunk(samples.sublist(i, end));
      await Future.delayed(_interChunkDelay);
    }

    if (_disposed) return;
    _socket.sendEndSignal();
    if (state.stage != UploadStage.done) {
      state = state.copyWith(stage: UploadStage.awaitingVerdict);
    }

    // Safety fallback only. Under normal conditions the result listener
    // already flips us to `done` the instant a result with is_final=true
    // arrives — this just guards against a dropped connection or a
    // clip so short the server never emits a final result.
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
