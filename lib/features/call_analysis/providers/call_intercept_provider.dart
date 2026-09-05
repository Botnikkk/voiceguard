import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/signaling_service.dart';
import '../../../core/network/voice_analysis_socket.dart';
import '../../../core/network/webrtc_config.dart';
import '../../../models/analysis_result.dart';

// NOTE: This used to host a dart:io HttpServer and wait for the sender
// phone to open a WebSocket to it directly (see git history). That only
// works when both devices are dart:io-capable phones on the same LAN with
// broadcast/unicast unblocked — it cannot run in a browser at all, since
// browsers have no API to bind a listening socket.
//
// It's been swapped for WebRTC: this side creates an RTCPeerConnection,
// joins a signaling "room" by code, and waits for the sender's offer.
// Once the peer connection's data channel opens, audio arrives as PCM16
// binary messages exactly like before, and everything downstream (decode,
// amplitude calc, forwarding into the backend analysis socket) is
// unchanged.

enum CallInterceptStage {
  waitingForCall,
  callActive,
  callEnded,
}

class CallInterceptState {
  final CallInterceptStage stage;
  final String? roomCode;
  final bool isSpeaking;
  final double amplitude;
  final AnalysisResult analysis;
  final int callSeconds;
  final String? errorMessage;

  const CallInterceptState({
    this.stage = CallInterceptStage.waitingForCall,
    this.roomCode,
    this.isSpeaking = false,
    this.amplitude = 0.0,
    this.analysis = const AnalysisResult(),
    this.callSeconds = 0,
    this.errorMessage,
  });

  CallInterceptState copyWith({
    CallInterceptStage? stage,
    String? roomCode,
    bool? isSpeaking,
    double? amplitude,
    AnalysisResult? analysis,
    int? callSeconds,
    String? errorMessage,
  }) {
    return CallInterceptState(
      stage: stage ?? this.stage,
      roomCode: roomCode ?? this.roomCode,
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
  final signaling = SignalingService(ApiConfig.signalingWsUrl);
  return CallInterceptNotifier(socket, signaling);
});

/// Joins a signaling room and waits for the paired phone/browser to send a
/// WebRTC offer. Once the resulting data channel opens, audio chunks are
/// forwarded into the same backend analysis socket the old HttpServer
/// version used — the state machine (waitingForCall / callActive /
/// callEnded), the call timer, and the escalate/save flow in
/// live_call_screen.dart are all unchanged.
class CallInterceptNotifier extends StateNotifier<CallInterceptState> {
  final VoiceAnalysisSocket _socket;
  final SignalingService _signaling;
  RTCPeerConnection? _pc;
  RTCDataChannel? _dataChannel;
  StreamSubscription? _signalingSub;
  Timer? _timer;
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  CallInterceptNotifier(this._socket, this._signaling)
      : super(const CallInterceptState()) {
    _socket.connect();
    _subscriptions.add(_socket.resultStream.listen((result) {
      if (_disposed) return;
      state = state.copyWith(analysis: result);
    }));
  }

  /// Starts waiting for the paired device in signaling room [room]. Call
  /// this as soon as the receiver role is chosen (mirrors the old
  /// auto-start-listening behavior) so the room code is ready to display.
  Future<void> startListening(String room) async {
    if (_pc != null || _disposed) return;
    try {
      state = state.copyWith(
        stage: CallInterceptStage.waitingForCall,
        roomCode: room,
        errorMessage: null,
      );

      _pc = await createPeerConnection(kIceServers);
      _pc!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        _signaling.send({'type': 'ice', 'candidate': candidate.toMap()});
      };
      _pc!.onDataChannel = (channel) => _bindDataChannel(channel);

      await _signaling.connectAndJoin(room);
      _signalingSub?.cancel();
      _signalingSub = _signaling.messages.listen(_handleSignal);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: '$e');
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> msg) async {
    if (_disposed || _pc == null) return;
    switch (msg['type']) {
      case 'offer':
        await _pc!.setRemoteDescription(
          RTCSessionDescription(msg['sdp'] as String, msg['sdpType'] as String),
        );
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _signaling.send(
            {'type': 'answer', 'sdp': answer.sdp, 'sdpType': answer.type});
        break;
      case 'ice':
        final c = msg['candidate'] as Map<String, dynamic>;
        await _pc!.addCandidate(RTCIceCandidate(
          c['candidate'] as String?,
          c['sdpMid'] as String?,
          c['sdpMLineIndex'] as int?,
        ));
        break;
      case 'room-full':
        if (_disposed) return;
        state = state.copyWith(
            errorMessage: 'That room code is already in use — try a new one.');
        break;
    }
  }

  void _bindDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onMessage = (RTCDataChannelMessage message) {
      if (_disposed) return;

      if (!message.isBinary) {
        final msg = jsonDecode(message.text);
        switch (msg['type']) {
          case 'meta':
            _beginCall();
            break;
          case 'end':
            _finishCall();
            break;
        }
        return;
      }

      final samples = _fromPcm16Bytes(message.binary);

      // Same amplitude calc the old VAD/bridge path used, so the "speech
      // detected" indicator behaves identically.
      double sumSquares = 0.0;
      for (final s in samples) {
        sumSquares += s * s;
      }
      final rms = samples.isEmpty ? 0.0 : (sumSquares / samples.length).abs();
      final normalized = (rms * 12.0).clamp(0.0, 1.0);
      final speaking = normalized > 0.15;

      state = state.copyWith(
        amplitude: speaking ? normalized : 0.05,
        isSpeaking: speaking,
      );

      // Forward straight into the existing backend pipeline.
      _socket.sendAudioChunk(samples);
    };
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

  /// Manual "End" button in the UI — ends the call locally even if the
  /// paired phone hasn't sent an 'end' message yet.
  Future<void> endSimulatedCall() async {
    await _dataChannel?.close();
    _dataChannel = null;
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

  /// Reset back to the waiting screen, ready for the next call. Keeps the
  /// same room code so the sender doesn't need a new one.
  void reset() {
    _timer?.cancel();
    _dataChannel?.close();
    _dataChannel = null;
    if (!_disposed) {
      state = CallInterceptState(roomCode: state.roomCode);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _signalingSub?.cancel();
    _dataChannel?.close();
    _pc?.close();
    _signaling.dispose();
    _socket.dispose();
    super.dispose();
  }
}
