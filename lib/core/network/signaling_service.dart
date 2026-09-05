import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin WebSocket client to the signaling relay server (see
/// signaling_server/server.js). Joins a room by code and exposes a stream
/// of incoming messages — 'joined', 'peer-joined', 'offer', 'answer',
/// 'ice', 'room-full' — so the WebRTC providers can drive the handshake
/// without knowing anything about sockets themselves.
///
/// This replaces device_discovery_service.dart. Where that service found
/// peers via UDP broadcast on the local subnet (which browsers can't do
/// at all), this finds peers by both sides typing/sharing the same room
/// code into a server both can reach — which works from any browser or
/// device, on any network, as long as they can reach the signaling server.
class SignalingService {
  final String serverUrl; // e.g. ws://192.168.1.10:8090

  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  SignalingService(this.serverUrl);

  Future<void> connectAndJoin(String room) async {
    await disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    await _channel!.ready;

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _messagesController.add(msg);
        } catch (_) {
          // Ignore malformed frames.
        }
      },
      onError: (e) => _messagesController.addError(e),
      onDone: () => _messagesController.add({'type': 'signaling-closed'}),
    );

    send({'type': 'join', 'room': room});
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
  }
}