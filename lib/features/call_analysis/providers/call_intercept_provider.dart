import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/voice_analysis_socket.dart';
import '../../../models/analysis_result.dart';
import 'audio_bridge_provider.dart' show kBridgePort;


enum CallInterceptStage {
  waitingForCall,
  callActive,
  callEnded,
}

class CallInterceptState {
  final CallInterceptStage stage;
  final String? localIp;
  final int port;
  final bool isSpeaking;
  final double amplitude;
  final AnalysisResult analysis;
  final int callSeconds;
  final String? errorMessage;

  const CallInterceptState({
    this.stage = CallInterceptStage.waitingForCall,
    this.localIp,
    this.port = kBridgePort,
    this.isSpeaking = false,
    this.amplitude = 0.0,
    this.analysis = const AnalysisResult(),
    this.callSeconds = 0,
    this.errorMessage,
  });

  CallInterceptState copyWith({
    CallInterceptStage? stage,
    String? localIp,
    int? port,
    bool? isSpeaking,
    double? amplitude,
    AnalysisResult? analysis,
    int? callSeconds,
    String? errorMessage,
  }) {
    return CallInterceptState(
      stage: stage ?? this.stage,
      localIp: localIp ?? this.localIp,
      port: port ?? this.port,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      amplitude: amplitude ?? this.amplitude,
      analysis: analysis ?? this.analysis,
      callSeconds: callSeconds ?? this.callSeconds,
      errorMessage: errorMessage,
    );
  }
}

final callInterceptProvider = StateNotifierProvider.autoDispose<
    CallInterceptNotifier, CallInterceptState>((ref) {
  final socket = VoiceAnalysisSocket(ApiConfig.voiceAnalysisWsUrl);
  return CallInterceptNotifier(socket);
});

class CallInterceptNotifier extends StateNotifier<CallInterceptState> {
  final VoiceAnalysisSocket _socket;
  HttpServer? _server;
  WebSocket? _callSocket;
  Timer? _timer;
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  CallInterceptNotifier(this._socket) : super(const CallInterceptState()) {
    _socket.connect();
    _subscriptions.add(_socket.resultStream.listen((result) {
      if (_disposed) return;
      state = state.copyWith(analysis: result);
    }));
  }

  Future<void> startListening({int port = kBridgePort}) async {
    if (_server != null || _disposed) return;
    try {
      final ip = await _findLocalIp();
      if (_disposed) return;
      if (ip == null) {
        state = state.copyWith(
          errorMessage: "Couldn't determine this phone's local IP — "
              'make sure Wi-Fi is connected.',
        );
        return;
      }
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      if (_disposed) return;
      state = state.copyWith(
        stage: CallInterceptStage.waitingForCall,
        localIp: ip,
        port: port,
        errorMessage: null,
      );

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleCallSocket(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..close();
        }
      });
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '$e');
    }
  }

  void _handleCallSocket(WebSocket socket) {
    _callSocket = socket;

    socket.listen(
      (data) {
        if (_disposed) return;
        if (data is String) {
          final msg = jsonDecode(data);
          switch (msg['type']) {
            case 'meta':
              _beginCall();
              break;
            case 'end':
              _finishCall();
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
          final speaking = normalized > 0.15;

          state = state.copyWith(
            amplitude: speaking ? normalized : 0.05,
            isSpeaking: speaking,
          );

          _socket.sendAudioChunk(samples);
        }
      },
      onDone: () {
        if (_disposed) return;
        if (state.stage == CallInterceptStage.callActive) _finishCall();
      },
      onError: (e) {
        if (_disposed) return;
        state = state.copyWith(errorMessage: '$e');
      },
    );
  }

  void _beginCall() {
    if (state.stage == CallInterceptStage.callActive) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      state = state.copyWith(callSeconds: state.callSeconds + 1);
    });
    state =
        state.copyWith(stage: CallInterceptStage.callActive, callSeconds: 0);
  }

  void _finishCall() {
    _timer?.cancel();
    _socket.sendEndSignal();
    if (!_disposed) {
      state = state.copyWith(
        stage: CallInterceptStage.callEnded,
        isSpeaking: false,
        amplitude: 0.0,
      );
    }
  }

  Future<void> endSimulatedCall() async {
    await _callSocket?.close();
    _callSocket = null;
    _finishCall();
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

  void reset() {
    _timer?.cancel();
    _callSocket?.close();
    _callSocket = null;
    if (!_disposed) {
      state = CallInterceptState(localIp: state.localIp, port: state.port);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _callSocket?.close();
    _server?.close(force: true);
    _socket.dispose();
    super.dispose();
  }
}
