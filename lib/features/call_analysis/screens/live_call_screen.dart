import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/recording_log.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/risk_gauge.dart';
import '../../../../core/network/device_discovery_service.dart';
import '../providers/call_intercept_provider.dart';
import '../providers/audio_bridge_provider.dart';
import '../providers/live_call_pairing_provider.dart';

class LiveCallInterceptScreen extends ConsumerStatefulWidget {
  const LiveCallInterceptScreen({super.key});

  @override
  ConsumerState<LiveCallInterceptScreen> createState() =>
      _LiveCallInterceptScreenState();
}

class _LiveCallInterceptScreenState
    extends ConsumerState<LiveCallInterceptScreen> {
  String _formattedTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _saveAndClose(CallInterceptState state) async {
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
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _backToRoleSelection() async {
    await ref.read(liveCallPairingProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(liveCallPairingProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeepest,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeepest,
        title: const Text('Intercept Live Call'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: _buildBody(pairing)),
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
          'it. Once you pick, this phone will find nearby phones running '
          'the opposite role automatically.',
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
  // Receiver flow - analysis UI, driven by callInterceptProvider
  // -------------------------------------------------------------------

  Widget _buildReceiverFlow() {
    final state = ref.watch(callInterceptProvider);

    Widget body;
    switch (state.stage) {
      case CallInterceptStage.waitingForCall:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Broadcasting as Receiver',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Nearby Sender phones will find this automatically. If '
              'discovery is blocked on this network, connect manually '
              'using the address below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (state.localIp != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgDeepest,
                  border: Border.all(
                      color: AppColors.textSecondary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.localIp}:${state.port}',
                  style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
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
                onPressed: () => _saveAndClose(state),
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
            const SizedBox(height: 28),
            CustomButton(
              label: 'Save to Log',
              icon: Icons.save_outlined,
              variant: ButtonVariant.primary,
              onPressed: () => _saveAndClose(state),
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Wait for Another Call',
              variant: ButtonVariant.outline,
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
        const SizedBox(height: 24),
        TextButton(
          onPressed: _backToRoleSelection,
          child: const Text('Back'),
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
      body = _buildNearbyReceiverPicker(pairing);
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
            variant: ButtonVariant.outline,
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
            variant: ButtonVariant.outline,
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
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            notifier.disconnect();
            _backToRoleSelection();
          },
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildNearbyReceiverPicker(LiveCallPairingState pairing) {
    if (pairing.errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error: ${pairing.errorMessage}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
        ],
      );
    }

    if (pairing.nearbyPeers.isEmpty) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Searching for nearby Receiver phones…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Nearby Receivers',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: pairing.nearbyPeers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final DiscoveredPeer peer = pairing.nearbyPeers[index];
              return _NearbyPeerTile(
                peer: peer,
                onTap: () => ref
                    .read(liveCallPairingProvider.notifier)
                    .connectToPeer(peer),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NearbyPeerTile extends StatelessWidget {
  final DiscoveredPeer peer;
  final VoidCallback onTap;

  const _NearbyPeerTile({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_android, color: AppColors.accentCyan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peer.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  Text('${peer.ip}:${peer.port}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
  