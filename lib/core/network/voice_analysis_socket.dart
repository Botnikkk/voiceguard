import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../models/analysis_result.dart';

class VoiceAnalysisSocket {
  WebSocketChannel? _channel;
  final String url;
  bool _isDisposed = false;
  Timer? _reconnectTimer;

  final _resultController = StreamController<AnalysisResult>.broadcast();
  Stream<AnalysisResult> get resultStream => _resultController.stream;

  VoiceAnalysisSocket(this.url);

  void connect() {
    if (_isDisposed) {
      return;
    }
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      debugPrint("[socket] connecting to $url");
      _channel!.stream.listen(
        (message) {
          // TEMP DEBUG: confirms raw frames are actually reaching this
          // listener at all, and what type/shape they are.
          debugPrint("[socket] raw message (${message.runtimeType}): "
              "${message is String ? message : '<binary ${(message as List).length} bytes>'}");
          try {
            final data = jsonDecode(message as String);
            final result = AnalysisResult.fromJson(data);
            debugPrint("[socket] parsed result: score=${result.smoothedScore} "
                "verdict=${result.verdict} confidence=${result.confidence}");
            _resultController.add(result);
          } catch (e, st) {
            debugPrint("[socket] FAILED to parse message: $e");
            debugPrint("$st");
          }
        },
        onDone: () {
          debugPrint("[socket] onDone fired — connection closed");
          _handleDisconnect();
        },
        onError: (error) => debugPrint("[socket] WebSocket Error: $error"),
      );
    } catch (e) {
      debugPrint("[socket] WebSocket Connection Error: $e");
    }
  }

  void sendAudioChunk(List<double> samples) {
    if (_channel == null || _isDisposed) return;
    final pcm16 = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcm16[i] = (samples[i] * 32767).clamp(-32768, 32767).toInt();
    }
    _channel!.sink.add(pcm16.buffer.asUint8List());
  }

  void sendEndSignal() {
    if (_isDisposed) return;
    _channel?.sink.add(Uint8List(0));
  }

  void _handleDisconnect() {
    if (_isDisposed) return;
    debugPrint("[socket] disconnected. Reconnecting in 2s...");
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), connect);
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _resultController.close();
  }
}
