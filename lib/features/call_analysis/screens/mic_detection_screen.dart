import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/recording_log.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/risk_gauge.dart';
import '../providers/risk_score_provider.dart';
import '../providers/voice_analysis_provider.dart';

/// "Detect audio from mic" — ambient listening via the device mic with
/// no awareness of call state. Least accurate of the three modes since
/// it's picking up whatever the mic hears, not a clean or call-targeted
/// signal.
class MicDetectionScreen extends ConsumerStatefulWidget {
  const MicDetectionScreen({super.key});

  @override
  ConsumerState<MicDetectionScreen> createState() => _MicDetectionScreenState();
}

class _MicDetectionScreenState extends ConsumerState<MicDetectionScreen> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceAnalysisProvider.notifier).startListening();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall(double finalRiskScore, {bool escalate = false}) async {
    await ref.read(voiceAnalysisProvider.notifier).stopListening();

    RecordingVerdict verdict = escalate
        ? RecordingVerdict.escalated
        : (finalRiskScore >= 0.7
            ? RecordingVerdict.flagged
            : RecordingVerdict.safe);

    final now = DateTime.now();
    final newLog = RecordingLog(
      id: 'm-${now.millisecondsSinceEpoch}',
      recordingName:
          'Mic Detection - ${DateFormat('MMM d, h:mm a').format(now)}',
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.report_gmailerrorred_rounded,
                color: AppColors.dangerRed, size: 40),
            const SizedBox(height: 12),
            const Text('Escalate to Fraud Team?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('This analysis will be forwarded to your organization.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            CustomButton(
                label: 'CONFIRM ESCALATION',
                icon: Icons.send_rounded,
                variant: ButtonVariant.danger,
                onPressed: () {
                  Navigator.of(context).pop();
                  _endCall(currentRiskScore, escalate: true);
                }),
            const SizedBox(height: 10),
            CustomButton(
                label: 'Cancel',
                variant: ButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text("$label: ",
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final riskScore = ref.watch(riskScoreProvider);
    final voiceState = ref.watch(voiceAnalysisProvider);
    final isDanger = riskScore >= 0.7;

    return PopScope(
      canPop: false,
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
                  AppColors.bgDeepest
                ],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildCallerHeader(voiceState.isSpeaking),
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('AI RISK ANALYSIS',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2)),
                        const SizedBox(height: 24),
                        RiskGauge(
                          score: riskScore,
                          label: voiceState.analysis.verdict,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildInfoChip(
                                "Verdict",
                                voiceState.analysis.verdict,
                                Icons.gavel_rounded),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                                "Confidence",
                                voiceState.analysis.confidence,
                                Icons.analytics_outlined),
                          ],
                        ),
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
                _buildAudioVisualizer(
                    voiceState.isSpeaking, voiceState.amplitude),
                const SizedBox(height: 30),
                _buildActionButtons(context, riskScore),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallerHeader(bool isSpeaking) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSpeaking
                ? AppColors.safeGreen.withValues(alpha: 0.1)
                : AppColors.bgSurface,
            border: Border.all(
                color: isSpeaking ? AppColors.safeGreen : AppColors.border,
                width: 1.5),
          ),
          child: Icon(Icons.mic,
              color: isSpeaking ? AppColors.safeGreen : AppColors.textSecondary,
              size: 44),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            isSpeaking ? "Speech Detected" : "Listening (Noise)...",
            key: ValueKey<bool>(isSpeaking),
            style: TextStyle(
                color: isSpeaking ? AppColors.safeGreen : AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Text(_formattedTime,
            style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
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
              child: Text('Synthetic voice patterns detected',
                  style: TextStyle(
                      color: AppColors.dangerRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildAudioVisualizer(bool isSpeaking, double amplitude) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(5, (index) {
          final variation = [0.6, 1.0, 0.8, 1.0, 0.6][index];
          final activeAmplitude = isSpeaking ? amplitude : (amplitude * 0.2);
          final barHeight = 4.0 + (activeAmplitude * 36 * variation);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: barHeight,
            decoration: BoxDecoration(
                color: isSpeaking ? AppColors.safeGreen : AppColors.accentCyan,
                borderRadius: BorderRadius.circular(4)),
          );
        }),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, double riskScore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(width: 12),
          CustomButton(
              label: 'Stop listening',
              icon: Icons.stop_circle_outlined,
              variant: ButtonVariant.danger,
              onPressed: () => _endCall(riskScore)),
          const SizedBox(height: 12),
          CustomButton(
              label: 'Escalate to Fraud Team',
              icon: Icons.local_police_outlined,
              variant: ButtonVariant.primary,
              onPressed: () => _showEscalationSheet(context, riskScore)),
        ],
      ),
    );
  }
}
