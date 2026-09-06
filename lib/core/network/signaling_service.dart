import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingService {
  final String serverUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _hasNotifiedUnavailable = false;

  final _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;

  final _unavailableController = StreamController<void>.broadcast();
  Stream<void> get onUnavailable => _unavailableController.stream;

  SignalingService(this.serverUrl);

  Future<void> connectAndJoin(String room) async {
    await disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      await _channel!.ready.timeout(const Duration(seconds: 5));
    } catch (e) {
      if (!_hasNotifiedUnavailable) {
        _hasNotifiedUnavailable = true;
        _unavailableController.add(null);
      }
      rethrow;
    }
    _hasNotifiedUnavailable = false;

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _messagesController.add(msg);
        } catch (_) {
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
    await _unavailableController.close();
  }
}
