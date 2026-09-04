import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredPeer {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String role;
  final DateTime lastSeen;

  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.role,
    required this.lastSeen,
  });
}


class DeviceDiscoveryService {
  static const int discoveryPort = 51235;
  static const Duration _advertiseInterval = Duration(seconds: 1);
  static const Duration _peerTimeout = Duration(seconds: 6);
  static const Duration _pruneInterval = Duration(seconds: 2);

  RawDatagramSocket? _advertiseSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _advertiseTimer;
  Timer? _pruneTimer;

  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();
  final Map<String, DiscoveredPeer> _peers = {};

  Stream<List<DiscoveredPeer>> get peers => _peersController.stream;


  Future<void> startAdvertising({
    required String role,
    required String deviceName,
    required String ip,
    required int servicePort,
  }) async {
    await stopAdvertising();
    _advertiseSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _advertiseSocket!.broadcastEnabled = true;

    final payload = utf8.encode(jsonEncode({
      'role': role,
      'name': deviceName,
      'ip': ip,
      'port': servicePort,
    }));

    void sendOnce() {
      try {
        _advertiseSocket?.send(
            payload, InternetAddress('255.255.255.255'), discoveryPort);
      } catch (_) {

      }
    }

    sendOnce();
    _advertiseTimer?.cancel();
    _advertiseTimer = Timer.periodic(_advertiseInterval, (_) => sendOnce());
  }

  Future<void> stopAdvertising() async {
    _advertiseTimer?.cancel();
    _advertiseTimer = null;
    _advertiseSocket?.close();
    _advertiseSocket = null;
  }


  Future<void> startListening({required String wantRole}) async {
    await stopListening();
    _peers.clear();

    _listenSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    _listenSocket!.broadcastEnabled = true;
    _listenSocket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _listenSocket?.receive();
      if (datagram == null) return;
      try {
        final msg = jsonDecode(utf8.decode(datagram.data)) as Map;
        if (msg['role'] != wantRole) return;
        final ip = (msg['ip'] as String?) ?? datagram.address.address;
        final port = msg['port'] as int;
        final name = (msg['name'] as String?);
        final peer = DiscoveredPeer(
          id: '$ip:$port',
          name: (name == null || name.isEmpty) ? ip : name,
          ip: ip,
          port: port,
          role: msg['role'] as String,
          lastSeen: DateTime.now(),
        );
        _peers[peer.id] = peer;
        _emit();
      } catch (_) {
      }
    });

    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(_pruneInterval, (_) {
      final now = DateTime.now();
      final before = _peers.length;
      _peers.removeWhere((_, p) => now.difference(p.lastSeen) > _peerTimeout);
      if (_peers.length != before) _emit();
    });
  }

  void _emit() {
    if (_peersController.isClosed) return;
    final list = _peers.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _peersController.add(list);
  }

  Future<void> stopListening() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _listenSocket?.close();
    _listenSocket = null;
    _peers.clear();
  }

  Future<void> dispose() async {
    await stopAdvertising();
    await stopListening();
    await _peersController.close();
  }
}
