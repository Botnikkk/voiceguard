// lib/core/network/voice_analysis_socket.dart
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
  bool _hasNotifiedUnavailable = false;
  Timer? _reconnectTimer;

  final _resultController = StreamController<AnalysisResult>.broadcast();
  Stream<AnalysisResult> get resultStream => _resultController.stream;

  final _unavailableController = StreamController<void>.broadcast();
  Stream<void> get onUnavailable => _unavailableController.stream;

  VoiceAnalysisSocket(this.url);

  Future<void> connect() async {
    if (_isDisposed) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready.timeout(const Duration(seconds: 5));
      if (_isDisposed) {
        channel.sink.close();
        return;
      }
      _channel = channel;
      _hasNotifiedUnavailable =
          false; // back up — a future drop can notify again

      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            final result = AnalysisResult.fromJson(data);
            _resultController.add(result);
          } catch (e) {
            debugPrint("[socket] FAILED to parse message: $e");
          }
        },
        onDone: _handleDisconnect,
        onError: (error) {
          debugPrint("[socket] WebSocket Error: $error");
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint("[socket] WebSocket Connection Error: $e");
      _handleDisconnect();
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
    _channel = null;
    if (!_hasNotifiedUnavailable) {
      _hasNotifiedUnavailable = true;
      _unavailableController.add(null);
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), connect);
  }

  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _resultController.close();
    _unavailableController.close();
  }
}
