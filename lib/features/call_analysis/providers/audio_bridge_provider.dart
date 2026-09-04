import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/voice_analysis_socket.dart';
import '../../../core/utils/wav_decoder.dart';
import '../../../core/utils/mp3_decoder.dart';
import '../../../models/analysis_result.dart';

const int kBridgePort = 51234;
const int kChunkSampleRate = 16000;
const int kSamplesPerChunk = kChunkSampleRate;

// ---------------------------------------------------------------------
// SENDER
// ---------------------------------------------------------------------

enum SenderStage { idle, connecting, connected, sending, finished, error }

class SenderState {
  final SenderStage stage;
  final String? fileName;
  final int totalSeconds;
  final int sentSeconds;
  final String? errorMessage;

  const SenderState({
    this.stage = SenderStage.idle,
    this.fileName,
    this.totalSeconds = 0,
    this.sentSeconds = 0,
    this.errorMessage,
  });

  SenderState copyWith({
    SenderStage? stage,
    String? fileName,
    int? totalSeconds,
    int? sentSeconds,
    String? errorMessage,
  }) {
    return SenderState(
      stage: stage ?? this.stage,
      fileName: fileName ?? this.fileName,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      sentSeconds: sentSeconds ?? this.sentSeconds,
      errorMessage: errorMessage,
    );
  }
}

final audioBridgeSenderProvider =
    StateNotifierProvider.autoDispose<AudioBridgeSenderNotifier, SenderState>(
        (ref) => AudioBridgeSenderNotifier());

class AudioBridgeSenderNotifier extends StateNotifier<SenderState> {
  AudioBridgeSenderNotifier() : super(const SenderState());

  WebSocketChannel? _channel;
  Timer? _pacer;
  bool _disposed = false;

  Future<void> connect(String receiverIp, {int port = kBridgePort}) async {
    state = state.copyWith(stage: SenderStage.connecting, errorMessage: null);
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://$receiverIp:$port'));
      await _channel!.ready; // throws if the receiver isn't reachable
      if (_disposed) return;
      state = state.copyWith(stage: SenderStage.connected);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        stage: SenderStage.error,
        errorMessage: "Couldn't reach $receiverIp:$port — $e",
      );
    }
  }

  Future<void> pickAndSendFile() async {
    if (_channel == null) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final picked = result.files.single;
    final bytes = picked.bytes!;
    final isMp3 = (picked.extension ?? '').toLowerCase() == 'mp3';

    state = state.copyWith(fileName: picked.name, sentSeconds: 0);

    late final DecodedAudio decoded;
    try {
      decoded =
          isMp3 ? await Mp3Decoder.decode(bytes) : WavDecoder.decode(bytes);
    } on WavDecodeException catch (e) {
      state = state.copyWith(stage: SenderStage.error, errorMessage: e.message);
      return;
    } catch (e) {
      state = state.copyWith(
        stage: SenderStage.error,
        errorMessage: 'Could not read or process this audio file.',
      );
      return;
    }

    if (_disposed) return;
    if (decoded.samples.isEmpty) {
      state = state.copyWith(
          stage: SenderStage.error, errorMessage: 'Audio file is empty.');
      return;
    }

    final totalSeconds = (decoded.samples.length / kSamplesPerChunk).ceil();
    state =
        state.copyWith(totalSeconds: totalSeconds, stage: SenderStage.sending);

    _channel!.sink.add(jsonEncode({
      'type': 'meta',
      'sampleRate': kChunkSampleRate,
      'totalSamples': decoded.samples.length,
      'fileName': picked.name,
    }));

    int offset = 0;
    int chunkIndex = 0;
    _pacer?.cancel();
    _pacer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || _channel == null) {
        timer.cancel();
        return;
      }
      if (offset >= decoded.samples.length) {
        timer.cancel();
        _channel!.sink.add(jsonEncode({'type': 'end'}));
        state = state.copyWith(stage: SenderStage.finished);
        return;
      }

      final end = (offset + kSamplesPerChunk).clamp(0, decoded.samples.length);
      final chunk = decoded.samples.sublist(offset, end);
      _channel!.sink.add(_toPcm16Bytes(chunk));
      offset = end;
      chunkIndex++;
      state = state.copyWith(sentSeconds: chunkIndex);
    });
  }

  Uint8List _toPcm16Bytes(List<double> samples) {
    final pcm16 = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcm16[i] = (samples[i] * 32767).clamp(-32768, 32767).toInt();
    }
    return pcm16.buffer.asUint8List();
  }

  void disconnect() {
    _pacer?.cancel();
    _channel?.sink.close();
    _channel = null;
    if (!_disposed) state = const SenderState();
  }

  @override
  void dispose() {
    _disposed = true;
    _pacer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------
// RECEIVER
// ---------------------------------------------------------------------

enum ReceiverStage {
  idle,
  listening,
  senderConnected,
  receiving,
  finished,
  error
}

class ReceiverState {
  final ReceiverStage stage;
  final String? localIp;
  final int port;
  final double amplitude;
  final AnalysisResult analysis;
  final int receivedSeconds;
  final int totalSeconds;
  final String? fileName;
  final String? errorMessage;

  const ReceiverState({
    this.stage = ReceiverStage.idle,
    this.localIp,
    this.port = kBridgePort,
    this.amplitude = 0.0,
    this.analysis = const AnalysisResult(),
    this.receivedSeconds = 0,
    this.totalSeconds = 0,
    this.fileName,
    this.errorMessage,
  });

  ReceiverState copyWith({
    ReceiverStage? stage,
    String? localIp,
    int? port,
    double? amplitude,
    AnalysisResult? analysis,
    int? receivedSeconds,
    int? totalSeconds,
    String? fileName,
    String? errorMessage,
  }) {
    return ReceiverState(
      stage: stage ?? this.stage,
      localIp: localIp ?? this.localIp,
      port: port ?? this.port,
      amplitude: amplitude ?? this.amplitude,
      analysis: analysis ?? this.analysis,
      receivedSeconds: receivedSeconds ?? this.receivedSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      fileName: fileName ?? this.fileName,
      errorMessage: errorMessage,
    );
  }
}

final audioBridgeReceiverProvider = StateNotifierProvider.autoDispose<
    AudioBridgeReceiverNotifier, ReceiverState>((ref) {
  final backendSocket = VoiceAnalysisSocket(ApiConfig.voiceAnalysisWsUrl);
  return AudioBridgeReceiverNotifier(backendSocket);
});

class AudioBridgeReceiverNotifier extends StateNotifier<ReceiverState> {
  final VoiceAnalysisSocket _backendSocket;
  HttpServer? _server;
  WebSocket? _senderSocket;
  StreamSubscription? _backendResultSub;
  bool _disposed = false;

  AudioBridgeReceiverNotifier(this._backendSocket)
      : super(const ReceiverState()) {
    _backendSocket.connect();
    _backendResultSub = _backendSocket.resultStream.listen((result) {
      if (_disposed) return;
      state = state.copyWith(analysis: result);
    });
  }

  Future<void> startListening({int port = kBridgePort}) async {
    try {
      final ip = await _findLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      if (_disposed) return;
      state = state.copyWith(
        stage: ReceiverStage.listening,
        localIp: ip,
        port: port,
        errorMessage: null,
      );

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleSenderConnection(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..close();
        }
      });
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(stage: ReceiverStage.error, errorMessage: '$e');
    }
  }

  void _handleSenderConnection(WebSocket socket) {
    _senderSocket = socket;
    if (!_disposed) {
      state = state.copyWith(stage: ReceiverStage.senderConnected);
    }

    int chunkIndex = 0;
    socket.listen(
      (data) {
        if (_disposed) return;
        if (data is String) {
          final msg = jsonDecode(data);
          switch (msg['type']) {
            case 'meta':
              final totalSamples = msg['totalSamples'] as int;
              state = state.copyWith(
                stage: ReceiverStage.receiving,
                fileName: msg['fileName'] as String?,
                totalSeconds: (totalSamples / kSamplesPerChunk).ceil(),
                receivedSeconds: 0,
              );
              chunkIndex = 0;
              break;
            case 'end':
              state =
                  state.copyWith(stage: ReceiverStage.finished, amplitude: 0.0);
              _backendSocket.sendEndSignal();
              break;
          }
        } else if (data is List<int>) {
          final bytes = Uint8List.fromList(data);
          final samples = _fromPcm16Bytes(bytes);

          double sumSquares = 0.0;
          for (final s in samples) {
            sumSquares += s * s;
          }
          final rms =
              samples.isEmpty ? 0.0 : (sumSquares / samples.length).abs();
          final normalized = (rms * 12.0).clamp(0.0, 1.0);

          chunkIndex++;
          state = state.copyWith(
            amplitude: normalized,
            receivedSeconds: chunkIndex,
          );

          _backendSocket.sendAudioChunk(samples);
        }
      },
      onDone: () {
        if (_disposed) return;
        state = state.copyWith(stage: ReceiverStage.listening, amplitude: 0.0);
      },
      onError: (e) {
        if (_disposed) return;
        state = state.copyWith(stage: ReceiverStage.error, errorMessage: '$e');
      },
    );
  }

  List<double> _fromPcm16Bytes(Uint8List bytes) {
    final pcm16 = ByteData.sublistView(bytes);
    final count = bytes.length ~/ 2;
    final samples = List<double>.filled(count, 0.0);
    for (int i = 0; i < count; i++) {
      samples[i] = pcm16.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  Future<String?> _findLocalIp() async {
    for (final interface in await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false)) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  Future<void> stopListening() async {
    await _senderSocket?.close();
    await _server?.close(force: true);
    _server = null;
    _senderSocket = null;
    if (!_disposed) state = const ReceiverState();
  }

  @override
  void dispose() {
    _disposed = true;
    _backendResultSub?.cancel();
    _senderSocket?.close();
    _server?.close(force: true);
    _backendSocket.dispose();
    super.dispose();
  }
}
