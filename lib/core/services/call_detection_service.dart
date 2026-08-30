import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';

import '../../features/call_analysis/screens/live_call_screen.dart';

/// Listens to the device's real phone state (ringing / active / ended) and
/// automatically pushes [LiveCallScreen] with the real caller number when a
/// genuine call comes in.
///
/// IMPORTANT — what this can and cannot do:
///   • It CAN tell you a real call is ringing, and (Android only) the real
///     caller number, via the OS's TelephonyManager.
///   • It CANNOT give you the call's raw audio. No third-party app on
///     Android or iOS can tap live cellular call audio — that's an OS/
///     carrier-level restriction, not a Flutter limitation. The risk score
///     shown on [LiveCallScreen] is still the simulated stream from
///     `risk_score_provider.dart` — wire that provider up to your model's
///     real inference feed if you move to a VoIP-based calling flow
///     instead (Twilio/Agora/WebRTC), where your app owns the audio.
///   • iOS does not expose incoming-call events or numbers to third-party
///     apps at all (Apple privacy sandboxing) — this service is
///     effectively Android-only. On iOS, only apps that place/receive
///     their own VoIP calls via CallKit can react to "call" events, and
///     even then it's your own VoIP audio, not carrier calls.
class CallDetectionService {
  CallDetectionService._();
  static final CallDetectionService instance = CallDetectionService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _isShowingCallScreen = false;

  /// Request the runtime permissions needed to observe call state and
  /// (optionally) read the caller's number, then start listening.
  Future<void> start() async {
    final statuses = await [
      Permission.phone,
      // Only request this if you actually need the caller's number —
      // Play Store requires a declared, justified use for READ_CALL_LOG /
      // READ_PHONE_STATE, and unnecessary requests can get an app rejected.
    ].request();

    if (statuses[Permission.phone]?.isGranted != true) {
      debugPrint('[CallDetectionService] Phone permission denied — cannot detect real calls.');
      return;
    }

    PhoneState.stream.listen(_onPhoneStateChanged);
  }

  void _onPhoneStateChanged(PhoneState event) {
    switch (event.status) {
      case PhoneStateStatus.CALL_INCOMING:
        _launchLiveCallScreen(event.number);
        break;
      case PhoneStateStatus.CALL_OUTGOING:
    // Handle outgoing call logic here
        break;
      case PhoneStateStatus.CALL_ENDED:
      case PhoneStateStatus.NOTHING:
        _isShowingCallScreen = false;
        break;
      case PhoneStateStatus.CALL_STARTED:
        // Call was answered — LiveCallScreen is already showing from the
        // CALL_INCOMING event above; nothing further to do here.
        break;

    }
  }

  void _launchLiveCallScreen(String? number) {
    if (_isShowingCallScreen) return;
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    _isShowingCallScreen = true;
    navState.push(
      MaterialPageRoute(
        builder: (_) => LiveCallScreen(
          callerName: 'Unknown Caller', // resolve against local contacts if desired
          callerNumber: number ?? 'Unknown number',
        ),
      ),
    );
  }
}