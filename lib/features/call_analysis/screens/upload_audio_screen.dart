import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/recording_log.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/risk_gauge.dart';
import '../providers/audio_upload_provider.dart';

class UploadAudioScreen extends ConsumerStatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  ConsumerState<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends ConsumerState<UploadAudioScreen> {
  Future<void> _pickAndAnalyze() async {
    // Calling pickFiles directly on FilePicker and allowing wav + mp3
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    await ref.read(audioUploadProvider.notifier).analyzeFile(file.name, bytes);
  }

  // Saves the finished analysis to the log. Called automatically the
  // instant analysis reaches `done` — no button press needed anymore.
  Future<void> _saveAnalysis(AudioUploadState state) async {
    final score = state.analysis.smoothedScore;
    final verdict =
        score >= 0.7 ? RecordingVerdict.flagged : RecordingVerdict.safe;
    final now = DateTime.now();
    final newLog = RecordingLog(
      id: 'u-${now.millisecondsSinceEpoch}',
      recordingName: state.fileName != null
          ? '${state.fileName}  - ${DateFormat('MMM d, h:mm a').format(now)}'
          : 'Upload - ${DateFormat('MMM d, h:mm a').format(now)}',
      timestamp: now,
      riskScore: score,
      verdict: verdict,
      durationInSeconds: 0,
    );
    await Hive.box<RecordingLog>("RecordingBox").add(newLog);
  }

  void _exit() {
    if (mounted) Navigator.of(context).pop();
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
    final state = ref.watch(audioUploadProvider);

    ref.listen<AudioUploadState>(audioUploadProvider, (previous, next) {
      final justFinished =
          next.stage == UploadStage.done && previous?.stage != UploadStage.done;
      if (justFinished) {
        _saveAnalysis(next);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgDeepest,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeepest,
        title: const Text('Upload Audio File'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: _buildBody(state)),
        ),
      ),
    );
  }

  Widget _buildBody(AudioUploadState state) {
    switch (state.stage) {
      case UploadStage.idle:
        return _buildPicker();

      case UploadStage.decoding:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accentCyan),
            SizedBox(height: 16),
            Text('Decoding audio…',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        );

      case UploadStage.streaming:
      case UploadStage.awaitingVerdict:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.fileName ?? '',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            RiskGauge(
              score: state.analysis.smoothedScore,
              label: state.analysis.verdict,
            ),
            const SizedBox(height: 16),
// Replace your Row with this Wrap widget:
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.0, // Replaces your SizedBox(width: 8)
              runSpacing: 8.0, // Adds vertical space if it wraps
              children: [
                _buildInfoChip(
                    "Verdict", state.analysis.verdict, Icons.gavel_rounded),
                _buildInfoChip("Confidence", state.analysis.confidence,
                    Icons.analytics_outlined),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: AppColors.bgSurfaceElevated,
              color: AppColors.accentCyan,
            ),
            const SizedBox(height: 8),
            Text('${(state.progress * 100).toStringAsFixed(0)}% analyzed',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        );

      case UploadStage.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.fileName ?? '',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            RiskGauge(
              score: state.analysis.smoothedScore,
              label: state.analysis.verdict,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                    "Verdict", state.analysis.verdict, Icons.gavel_rounded),
                const SizedBox(width: 8),
                _buildInfoChip("Confidence", state.analysis.confidence,
                    Icons.analytics_outlined),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Saved to your log',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 28),
            CustomButton(
              label: 'Analyze Another File',
              icon: Icons.refresh,
              variant: ButtonVariant.primary,
              onPressed: () => ref.read(audioUploadProvider.notifier).reset(),
            ),
            const SizedBox(height: 10),
            CustomButton(
              label: 'Exit',
              variant: ButtonVariant.outline,
              onPressed: _exit,
            ),
          ],
        );

      case UploadStage.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.dangerRed, size: 40),
            const SizedBox(height: 12),
            Text(state.errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Try Again',
              variant: ButtonVariant.outline,
              onPressed: () => ref.read(audioUploadProvider.notifier).reset(),
            ),
          ],
        );
    }
  }

  Widget _buildPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.upload_file, color: AppColors.safeGreen, size: 48),
        const SizedBox(height: 16),
        const Text(
            'Upload a WAV or MP3 recording for the most accurate analysis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        CustomButton(
          label: 'Choose File',
          icon: Icons.folder_open,
          variant: ButtonVariant.primary,
          onPressed: _pickAndAnalyze,
        ),
      ],
    );
  }
}
