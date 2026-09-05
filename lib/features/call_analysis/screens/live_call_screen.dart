import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:voiceguard/core/widgets/web_constraint.dart';

import '../../../models/recording_log.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/risk_gauge.dart';
import '../providers/call_intercept_provider.dart';
import '../providers/audio_bridge_provider.dart';
import '../providers/live_call_pairing_provider.dart';

/// "Intercept live call". Opens by asking the user whether this phone is
/// the Sender (streams test call audio out) or the Receiver (hosts the
/// bridge and runs analysis), then auto-pairs with a nearby phone of the
/// opposite role over LAN broadcast instead of typing an IP address.
///
/// Role selection + pairing lives in live_call_pairing_provider.dart.
/// The actual audio transport is unchanged: Receiver still drives
/// call_intercept_provider.dart (WebSocket server -> backend analysis),
/// Sender still drives audio_bridge_provider.dart's sender (WebSocket
/// client streaming a picked file at real-time pace).
class LiveCallInterceptScreen extends ConsumerStatefulWidget {
  const LiveCallInterceptScreen({super.key});

  @override
  ConsumerState<LiveCallInterceptScreen> createState() =>
      _LiveCallInterceptScreenState();
}

class _LiveCallInterceptScreenState
    extends ConsumerState<LiveCallInterceptScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _formattedTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _saveLog(CallInterceptState state) async {
    final score = state.analysis.smoothedScore;
    final verdict =
        score >= 0.7 ? RecordingVerdict.flagged : RecordingVerdict.safe;
    final now = DateTime.now();
    final newLog = RecordingLog(
      id: 'i-${now.millisecondsSinceEpoch}',
      recordingName: 'Call - ${DateFormat('MMM d, h:mm a').format(now)}',
      timestamp: now,
      riskScore: score,
      verdict: verdict,
      durationInSeconds: state.callSeconds,
    );
    await Hive.box<RecordingLog>("RecordingBox").add(newLog);
  }

  Future<void> _backToRoleSelection() async {
    await ref.read(liveCallPairingProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for call ending to auto-save the log
    ref.listen<CallInterceptState>(callInterceptProvider, (previous, next) {
      if (previous?.stage == CallInterceptStage.callActive &&
          next.stage == CallInterceptStage.callEnded) {
        _saveLog(next);
      }
    });

    final pairing = ref.watch(liveCallPairingProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeepest,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeepest,
        title: const Text('Intercept Live Call'),
      ),
      body: WebConstraint(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: _buildBody(pairing)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LiveCallPairingState pairing) {
    switch (pairing.role) {
      case LiveCallRole.none:
        return _buildRolePicker(pairing);
      case LiveCallRole.receiver:
        return _buildReceiverFlow();
      case LiveCallRole.sender:
        return _buildSenderFlow(pairing);
    }
  }

  // -------------------------------------------------------------------
  // Role picker
  // -------------------------------------------------------------------

  Widget _buildRolePicker(LiveCallPairingState pairing) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.phone_in_talk_outlined,
            color: AppColors.accentCyan, size: 48),
        const SizedBox(height: 16),
        const Text('Is this phone the Sender or Receiver?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Receiver hosts the analysis. Sender streams test call audio to '
          'it. After you pick, the Receiver will show a short code — enter '
          'it on the Sender device to connect.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        CustomButton(
          label: 'This is the Receiver',
          icon: Icons.call_received_rounded,
          variant: ButtonVariant.primary,
          onPressed: () =>
              ref.read(liveCallPairingProvider.notifier).chooseReceiver(),
        ),
        const SizedBox(height: 12),
        CustomButton(
          label: 'This is the Sender',
          icon: Icons.upload_rounded,
          variant: ButtonVariant.outline,
          onPressed: () =>
              ref.read(liveCallPairingProvider.notifier).chooseSender(),
        ),
        if (pairing.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text('Error: ${pairing.errorMessage}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------
  // Receiver flow — unchanged analysis UI, driven by callInterceptProvider
  // -------------------------------------------------------------------

  Widget _buildReceiverFlow() {
    final state = ref.watch(callInterceptProvider);

    Widget body;
    switch (state.stage) {
      case CallInterceptStage.waitingForCall:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Waiting for the other device',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Enter this code on the Sender device to connect.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (state.roomCode != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgDeepest,
                  border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.roomCode!,
                  style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text('Error: ${state.errorMessage}',
                  style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        );
        break;

      case CallInterceptStage.callActive:
        final isDanger = state.analysis.smoothedScore >= 0.7;
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formattedTime(state.callSeconds),
                style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            RiskGauge(
              score: state.analysis.smoothedScore,
              label: state.analysis.verdict,
            ),
            const SizedBox(height: 16),
            Text(
              state.isSpeaking ? 'Speech detected' : 'Listening…',
              style: TextStyle(
                  color: state.isSpeaking
                      ? AppColors.safeGreen
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'End Call',
              icon: Icons.call_end_rounded,
              variant: ButtonVariant.outline,
              onPressed: () =>
                  ref.read(callInterceptProvider.notifier).endSimulatedCall(),
            ),
            if (isDanger) ...[
              const SizedBox(height: 12),
              CustomButton(
                label: 'Escalate to Fraud Team',
                icon: Icons.local_police_outlined,
                variant: ButtonVariant.danger,
                onPressed: () =>
                    // Ending the call triggers the auto-save seamlessly.
                    ref.read(callInterceptProvider.notifier).endSimulatedCall(),
              ),
            ],
          ],
        );
        break;

      case CallInterceptStage.callEnded:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Call ended',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            RiskGauge(
              score: state.analysis.smoothedScore,
              label: state.analysis.verdict,
            ),
            const SizedBox(height: 16),
            const Text('Log saved automatically.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            CustomButton(
              label: 'Wait for Another Call',
              variant: ButtonVariant.primary,
              onPressed: () => ref.read(callInterceptProvider.notifier).reset(),
            ),
          ],
        );
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        const SizedBox(height: 16),
        CustomButton(
          label: 'Back',
          variant: ButtonVariant.outline,
          onPressed: _backToRoleSelection,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Sender flow — nearby-receiver picker, then existing bridge sender UI
  // -------------------------------------------------------------------

  Widget _buildSenderFlow(LiveCallPairingState pairing) {
    final state = ref.watch(audioBridgeSenderProvider);
    final notifier = ref.read(audioBridgeSenderProvider.notifier);

    Widget body;
    if (state.stage == SenderStage.idle) {
      body = _buildRoomCodeEntry(pairing);
    } else if (state.stage == SenderStage.connecting) {
      body = const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Connecting…', style: TextStyle(color: AppColors.textSecondary)),
        ],
      );
    } else if (state.stage == SenderStage.connected) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Connected to receiver.',
              style: TextStyle(color: AppColors.safeGreen)),
          const SizedBox(height: 16),
          CustomButton(
            label: 'Pick Audio File & Send',
            icon: Icons.audio_file_outlined,
            variant: ButtonVariant.primary,
            onPressed: notifier.pickAndSendFile,
          ),
        ],
      );
    } else if (state.stage == SenderStage.sending) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(state.fileName ?? '',
              style: const TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.totalSeconds == 0
                ? null
                : state.sentSeconds / state.totalSeconds,
          ),
          const SizedBox(height: 8),
          Text('${state.sentSeconds}s / ${state.totalSeconds}s sent',
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      );
    } else if (state.stage == SenderStage.finished) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Finished sending.',
              style: TextStyle(color: AppColors.safeGreen)),
          const SizedBox(height: 16),
          CustomButton(
            label: 'Send Another File',
            variant: ButtonVariant.primary,
            onPressed: notifier.pickAndSendFile,
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: ${state.errorMessage}',
              style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 16),
          CustomButton(
            label: 'Retry',
            variant: ButtonVariant.primary,
            onPressed: () =>
                ref.read(liveCallPairingProvider.notifier).chooseSender(),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Sender',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        body,
        const SizedBox(height: 16),
        CustomButton(
          label: 'Back',
          variant: ButtonVariant.outline,
          onPressed: () {
            notifier.disconnect();
            _backToRoleSelection();
          },
        ),
      ],
    );
  }

  Widget _buildRoomCodeEntry(LiveCallPairingState pairing) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter the code shown on the Receiver device',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 4),
          decoration: InputDecoration(
            hintText: '000000',
            filled: true,
            fillColor: AppColors.bgDeepest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.3)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          label: 'Connect',
          icon: Icons.link_rounded,
          variant: ButtonVariant.primary,
          onPressed: () => ref
              .read(liveCallPairingProvider.notifier)
              .connectWithCode(_codeController.text),
        ),
        if (pairing.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text('Error: ${pairing.errorMessage}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }
}
