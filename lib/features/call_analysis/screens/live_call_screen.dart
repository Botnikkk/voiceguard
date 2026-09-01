import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/risk_gauge.dart';
import '../providers/risk_score_provider.dart';

class LiveCallScreen extends ConsumerWidget {
  /// Caller's display name. Real telecom calls rarely expose a name (only
  /// a number) unless it matches a local contact — resolve that lookup
  /// yourself and pass it in, or fall back to "Unknown Caller".

  /// Real caller number when launched from an actual incoming call via
  /// [CallDetectionService]; a dummy number for the "Simulate" demo path.

  const LiveCallScreen({
    super.key,
  });

  void _showEscalationSheet(BuildContext context) {
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Cancel',
              variant: ButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskScore = ref.watch(riskScoreProvider);
    final riskColor = AppColors.riskColor(riskScore);
    final isDanger = riskScore >= 0.7;

    return PopScope(
      canPop: true,
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
                _buildDetectionSignals(riskScore),
                const SizedBox(height: 20),
                _buildActionButtons(context, riskColor),
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
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgSurface,
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child:
              const Icon(Icons.mic, color: AppColors.textSecondary, size: 44),
        ),
        const SizedBox(height: 14),
        const Text(
          "Listening...",
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        const SizedBox(height: 6),
        const _CallTimer(),
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

  Widget _buildDetectionSignals(double riskScore) {
    final signals = [
      ('Spectral Anomaly', riskScore > 0.3),
      ('Pitch Consistency', riskScore > 0.55),
      ('Background Noise Match', riskScore > 0.7),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: signals.map((s) {
          final flagged = s.$2;
          final color = flagged ? AppColors.dangerRed : AppColors.safeGreen;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(flagged ? Icons.close_rounded : Icons.check_rounded,
                    color: color, size: 13),
                const SizedBox(width: 4),
                Text(s.$1,
                    style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color riskColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(width: 12),
          CustomButton(
            label: 'Stop listening',
            icon: Icons.stop_circle_outlined,
            variant: ButtonVariant.danger,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Escalate to Fraud Team',
            icon: Icons.local_police_outlined,
            variant: ButtonVariant.primary,
            onPressed: () => _showEscalationSheet(context),
          ),
        ],
      ),
    );
  }
}

class _CallTimer extends StatefulWidget {
  const _CallTimer();

  @override
  State<_CallTimer> createState() => _CallTimerState();
}

class _CallTimerState extends State<_CallTimer> {
  int _seconds = 0;
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1), (i) => i + 1);
    _ticker.listen((s) {
      if (mounted) setState(() => _seconds = s);
    });
  }

  String get _formatted {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: const TextStyle(
          color: AppColors.accentCyan,
          fontSize: 12.5,
          fontWeight: FontWeight.w600),
    );
  }
}
