import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_bridge_provider.dart' show audioBridgeSenderProvider;
import 'call_intercept_provider.dart'
    show callInterceptProvider, CallInterceptState;

enum LiveCallRole { none, sender, receiver }

class LiveCallPairingState {
  final LiveCallRole role;
  final String? roomCode;
  final String? errorMessage;

  const LiveCallPairingState({
    this.role = LiveCallRole.none,
    this.roomCode,
    this.errorMessage,
  });

  LiveCallPairingState copyWith({
    LiveCallRole? role,
    String? roomCode,
    String? errorMessage,
  }) {
    return LiveCallPairingState(
      role: role ?? this.role,
      roomCode: roomCode ?? this.roomCode,
      errorMessage: errorMessage,
    );
  }
}

final liveCallPairingProvider = StateNotifierProvider.autoDispose<
    LiveCallPairingNotifier, LiveCallPairingState>((ref) {
  return LiveCallPairingNotifier(ref);
});

/// Drives the "ask sender or receiver, then pair" flow in front of
/// live_call_screen.dart. It owns role selection and the room code only —
/// the actual audio transport is still whichever existing provider matches
/// the chosen role:
///
/// - Receiver -> [callInterceptProvider] (creates the WebRTC peer
///   connection the analysis pipeline reads from). This notifier
///   generates the room code and displays it.
/// - Sender -> [audioBridgeSenderProvider] (creates the WebRTC offer and
///   streams a picked test file at real-time pace). This notifier just
///   hands the typed-in room code straight to `connect()`.
///
/// This replaces the old LAN-broadcast discovery
/// (device_discovery_service.dart, deleted) — instead of finding a nearby
/// device automatically, the two sides share a short code (shown on the
/// receiver, typed on the sender), and a signaling server in between
/// relays the WebRTC handshake. This works between a phone and a Chrome
/// tab, and across different networks, neither of which LAN broadcast
/// could ever do.
class LiveCallPairingNotifier extends StateNotifier<LiveCallPairingState> {
  final Ref _ref;

  // Holds callInterceptProvider (autoDispose) open for as long as this
  // pairing flow needs it. Without this, `ref.read(...).startListening()`
  // below registers zero listeners, and Riverpod disposes the notifier
  // mid-flight — before the peer connection is even created — since the
  // widget doesn't start watching callInterceptProvider until its next
  // rebuild, a full frame later.
  ProviderSubscription<CallInterceptState>? _interceptSub;
  bool _disposed = false;

  LiveCallPairingNotifier(this._ref) : super(const LiveCallPairingState());

  /// This phone is the one that will be analyzed *by* the other side —
  /// i.e. it waits for a WebRTC offer and runs the analysis.
  Future<void> chooseReceiver() async {
    final room = _generateRoomCode();
    state = state.copyWith(
        role: LiveCallRole.receiver, roomCode: room, errorMessage: null);
    try {
      _interceptSub?.close();
      _interceptSub = _ref.listen<CallInterceptState>(
        callInterceptProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await _ref.read(callInterceptProvider.notifier).startListening(room);
      // Any failure here is surfaced on callInterceptProvider's own
      // errorMessage, which live_call_screen.dart's receiver flow reads
      // directly.
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '$e');
    }
  }

  /// This phone/browser will stream test audio *to* a receiver, identified
  /// by the room code shown on the receiver's screen.
  void chooseSender() {
    state = state.copyWith(
        role: LiveCallRole.sender, roomCode: null, errorMessage: null);
  }

  /// Called when the sender submits the room code they were given.
  Future<void> connectWithCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
          errorMessage: 'Enter the code shown on the receiver phone.');
      return;
    }
    state = state.copyWith(roomCode: trimmed, errorMessage: null);
    await _ref.read(audioBridgeSenderProvider.notifier).connect(trimmed);
  }

  String _generateRoomCode() {
    final rand = Random();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  /// Back button — returns to role selection.
  /// (The underlying transport provider — callInterceptProvider or
  /// audioBridgeSenderProvider — is autoDispose and tears itself down
  /// once the screen stops watching it and this releases its own hold.)
  Future<void> reset() async {
    _interceptSub?.close();
    _interceptSub = null;
    if (!_disposed) state = const LiveCallPairingState();
  }

  @override
  void dispose() {
    _disposed = true;
    _interceptSub?.close();
    super.dispose();
  }
}
