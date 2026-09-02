import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';

import '../../../core/services/settings_service.dart';
import '../../../models/recording_log.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/risk_gauge.dart';
import '../providers/risk_score_provider.dart';

class LiveCallScreen extends ConsumerStatefulWidget {
  const LiveCallScreen({super.key});

  @override
  ConsumerState<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends ConsumerState<LiveCallScreen> {
  int _seconds = 0;
  Timer? _timer;

  late final VadHandler _vadHandler;
  bool _vadStarted = false;

  bool _isSpeaking = false;
  double _amplitude = 0.0;

  final List<StreamSubscription> _vadSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _vadHandler = VadHandler.create(isDebug: false);
    _setupVadHandler();
    _startListening();
  }

  void _setupVadHandler() {
    // Fires the moment the model thinks speech might have started. Can be
    // a misfire on very short blips - see onVADMisfire below.
    _vadSubscriptions.add(_vadHandler.onSpeechStart.listen((_) {
      if (mounted) setState(() => _isSpeaking = true);
    }));

    // Fires once enough consecutive frames confirm this is real speech,
    // not a brief blip. Good hook point if you want a stricter "is
    // actually talking" signal than onSpeechStart alone.
    _vadSubscriptions.add(_vadHandler.onRealSpeechStart.listen((_) {
      // no-op for now - reserved for tightening the UI state later if
      // onSpeechStart proves too eager in practice.
    }));

    // Fires when a confirmed speech segment ends, with the full utterance
    // as PCM float samples. This is the natural point to hand audio off
    // to your backend AI analysis.
    _vadSubscriptions
        .add(_vadHandler.onSpeechEnd.listen((List<double> samples) {
      if (mounted) setState(() => _isSpeaking = false);

      // [STEP 3 PLUMBING LIVES HERE]
      // `samples` is the complete speech utterance (16kHz mono, float).
      // webSocket.add(samples);
    }));

    // Fires when speech was tentatively detected (onSpeechStart already
    // fired) but didn't last long enough to count as real speech - the
    // package's own false-positive filter. Just resets our UI state.
    _vadSubscriptions.add(_vadHandler.onVADMisfire.listen((_) {
      if (mounted) setState(() => _isSpeaking = false);
    }));

    // Fires for every processed audio frame with a speech probability and
    // the raw frame samples - this is what drives the amplitude
    // visualizer bars now, instead of a separate getAmplitude() poll.
    _vadSubscriptions.add(_vadHandler.onFrameProcessed.listen((frameData) {
      final frame = frameData.frame;
      if (frame.isEmpty) return;

      double sumSquares = 0.0;
      for (final sample in frame) {
        sumSquares += sample * sample;
      }
      final double rms = math.sqrt(sumSquares / frame.length);

      // Frame samples are normalized floats in roughly [-1, 1], so RMS is
      // typically small; scale it up for a visually responsive bar.
      final double normalized = (rms * 6.0).clamp(0.0, 1.0);

      if (mounted) {
        setState(() {
          _amplitude = normalized < 0.05 ? 0.05 : normalized;
        });
      }
    }));

    _vadSubscriptions.add(_vadHandler.onError.listen((String message) {
      debugPrint('VAD error: $message');
    }));
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    // 1. Fetch the 0-100 value from your SettingsService
    final sensitivity = SettingsService.instance.sensitivity.value;

    // 2. Map the 0-100 slider to a 0.9 to 0.1 VAD threshold
    // 0% sensitivity = 0.9 threshold (Strict, loud rooms)
    // 50% sensitivity = 0.5 threshold (Default)
    // 100% sensitivity = 0.1 threshold (Highly sensitive, quiet rooms)
    final double positiveThreshold = 0.9 - ((sensitivity / 100) * 0.8);

    // Negative threshold is usually ~0.15 lower than positive to prevent flickering
    final double negativeThreshold =
        (positiveThreshold - 0.15).clamp(0.05, 0.95);

    await _vadHandler.startListening(
      model: 'v5',
      positiveSpeechThreshold: positiveThreshold,
      negativeSpeechThreshold: negativeThreshold,
      minSpeechFrames: 3,
      redemptionFrames: 8,
    );

    if (mounted) setState(() => _vadStarted = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final sub in _vadSubscriptions) {
      sub.cancel();
    }
    // dispose() is async, but Widget.dispose() is sync - fire and forget.
    _vadHandler.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall(double finalRiskScore, {bool escalate = false}) async {
    if (_vadStarted) {
      await _vadHandler.stopListening();
    }

    RecordingVerdict verdict = escalate
        ? RecordingVerdict.escalated
        : (finalRiskScore >= 0.7
            ? RecordingVerdict.flagged
            : RecordingVerdict.safe);

    final now = DateTime.now();
    final timeString = DateFormat('MMM d, h:mm a').format(now);

    final newLog = RecordingLog(
      id: 'c-${now.millisecondsSinceEpoch}',
      recordingName: 'Recording - $timeString',
      timestamp: now,
      riskScore: finalRiskScore,
      verdict: verdict,
      durationInSeconds: _seconds,
    );

    Hive.box<RecordingLog>("RecordingBox").add(newLog);

    if (mounted) Navigator.of(context).pop();
  }

  void _showEscalationSheet(BuildContext context, double currentRiskScore) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.report_gmailerrorred_rounded,
                color: AppColors.dangerRed, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Escalate to Fraud Team?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'This call recording, risk analysis and caller metadata will be forwarded to your organization\'s fraud response team immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'CONFIRM ESCALATION',
              icon: Icons.send_rounded,
              variant: ButtonVariant.danger,
              onPressed: () {
                Navigator.of(context).pop(); // Close bottom sheet
                _endCall(currentRiskScore,
                    escalate: true); // Save & close screen
              },
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Cancel',
              variant: ButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riskScore = ref.watch(riskScoreProvider);
    final riskColor = AppColors.riskColor(riskScore);
    final isDanger = riskScore >= 0.7;

    return PopScope(
      canPop: false, // Prevent accidental back button presses during a "call"
      child: Scaffold(
        backgroundColor: AppColors.bgDeepest,
        body: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDanger
                      ? AppColors.dangerRedDim.withValues(alpha: 0.5)
                      : AppColors.bgDeepest,
                  AppColors.bgDeepest,
                ],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildCallerHeader(context),
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'AI RISK ANALYSIS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        RiskGauge(score: riskScore),
                        const SizedBox(height: 28),
                        AnimatedOpacity(
                          opacity: isDanger ? 1 : 0,
                          duration: const Duration(milliseconds: 400),
                          child: _buildDangerBanner(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Audio Visualizer Bar
                _buildAudioVisualizer(),

                const SizedBox(height: 30),
                _buildActionButtons(context, riskColor, riskScore),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallerHeader(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Subtly change background when speaking
            color: _isSpeaking
                ? AppColors.safeGreen.withValues(alpha: 0.1)
                : AppColors.bgSurface,
            border: Border.all(
                // Highlight border when speaking
                color: _isSpeaking ? AppColors.safeGreen : AppColors.border,
                width: 1.5),
          ),
          child: Icon(Icons.mic,
              color:
                  _isSpeaking ? AppColors.safeGreen : AppColors.textSecondary,
              size: 44),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            // Change text dynamically based on VAD state
            _isSpeaking ? "Speech Detected" : "Listening (Noise)...",
            key: ValueKey<bool>(_isSpeaking),
            style: TextStyle(
                color:
                    _isSpeaking ? AppColors.safeGreen : AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formattedTime,
          style: const TextStyle(
              color: AppColors.accentCyan,
              fontSize: 12.5,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDangerBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, color: AppColors.dangerRed, size: 18),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Synthetic voice patterns detected',
              style: TextStyle(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioVisualizer() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (index) {
          // Add slight variations so the bars bounce differently like a real wave
          final variation = [0.6, 1.0, 0.8, 1.0, 0.6][index];

          // If speaking, bars jump higher. If noise, they stay low.
          final activeAmplitude = _isSpeaking ? _amplitude : (_amplitude * 0.2);
          final barHeight = 4.0 + (activeAmplitude * 36 * variation);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: barHeight,
            decoration: BoxDecoration(
              // Turn green when speaking, cyan when silent/noise
              color: _isSpeaking ? AppColors.safeGreen : AppColors.accentCyan,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, Color riskColor, double riskScore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(width: 12),
          CustomButton(
            label: 'Stop listening',
            icon: Icons.stop_circle_outlined,
            variant: ButtonVariant.danger,
            // Trigger save function natively
            onPressed: () => _endCall(riskScore),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Escalate to Fraud Team',
            icon: Icons.local_police_outlined,
            variant: ButtonVariant.primary,
            onPressed: () => _showEscalationSheet(context, riskScore),
          ),
        ],
      ),
    );
  }
}
