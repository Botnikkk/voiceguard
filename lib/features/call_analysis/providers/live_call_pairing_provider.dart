import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/device_discovery_service.dart';
import 'audio_bridge_provider.dart' show audioBridgeSenderProvider, kBridgePort;
import 'call_intercept_provider.dart'
    show callInterceptProvider, CallInterceptState;

enum LiveCallRole { none, sender, receiver }

class LiveCallPairingState {
  final LiveCallRole role;
  final List<DiscoveredPeer> nearbyPeers;
  final String? errorMessage;

  const LiveCallPairingState({
    this.role = LiveCallRole.none,
    this.nearbyPeers = const [],
    this.errorMessage,
  });

  LiveCallPairingState copyWith({
    LiveCallRole? role,
    List<DiscoveredPeer>? nearbyPeers,
    String? errorMessage,
  }) {
    return LiveCallPairingState(
      role: role ?? this.role,
      nearbyPeers: nearbyPeers ?? this.nearbyPeers,
      errorMessage: errorMessage,
    );
  }
}

final liveCallPairingProvider = StateNotifierProvider.autoDispose<
    LiveCallPairingNotifier, LiveCallPairingState>((ref) {
  return LiveCallPairingNotifier(ref);
});
class LiveCallPairingNotifier extends StateNotifier<LiveCallPairingState> {
  final Ref _ref;
  final DeviceDiscoveryService _discovery = DeviceDiscoveryService();
  StreamSubscription<List<DiscoveredPeer>>? _peersSub;
  ProviderSubscription<CallInterceptState>? _interceptSub;
  bool _disposed = false;

  LiveCallPairingNotifier(this._ref) : super(const LiveCallPairingState());


  Future<void> chooseReceiver() async {
    state = state.copyWith(
        role: LiveCallRole.receiver, nearbyPeers: const [], errorMessage: null);
    try {
      _interceptSub?.close();
      _interceptSub = _ref.listen<CallInterceptState>(
        callInterceptProvider,
        (_, __) {},
        fireImmediately: true,
      );

      await _ref.read(callInterceptProvider.notifier).startListening();
      final ip = _ref.read(callInterceptProvider).localIp;
      if (ip == null) {
        return;
      }
      await _discovery.startAdvertising(
        role: 'receiver',
        deviceName: 'Receiver ${ip.split('.').last}',
        ip: ip,
        servicePort: kBridgePort,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '$e');
    }
  }

  Future<void> chooseSender() async {
    state = state.copyWith(
        role: LiveCallRole.sender, nearbyPeers: const [], errorMessage: null);
    try {
      await _discovery.startListening(wantRole: 'receiver');
      _peersSub?.cancel();
      _peersSub = _discovery.peers.listen((peers) {
        if (_disposed) return;
        state = state.copyWith(nearbyPeers: peers);
      });
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '$e');
    }
  }

  Future<void> connectToPeer(DiscoveredPeer peer) async {
    await _ref
        .read(audioBridgeSenderProvider.notifier)
        .connect(peer.ip, port: peer.port);
  }

  Future<void> reset() async {
    _peersSub?.cancel();
    _peersSub = null;
    _interceptSub?.close();
    _interceptSub = null;
    await _discovery.stopAdvertising();
    await _discovery.stopListening();
    if (!_disposed) state = const LiveCallPairingState();
  }

  @override
  void dispose() {
    _disposed = true;
    _peersSub?.cancel();
    _interceptSub?.close();
    _discovery.dispose();
    super.dispose();
  }
}
