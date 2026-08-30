import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/call_log.dart';
import '../../call_analysis/screens/live_call_screen.dart';
import '../../logs/screens/logs_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/call_summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = CallLog.dummyList();
    final safeCount = logs.where((l) => l.verdict == CallVerdict.safe).length;
    final flaggedCount = logs.where((l) => l.verdict != CallVerdict.safe).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOICEGAURD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _buildSystemStatusCard(context),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SummaryStatCard(
                    label: 'Safe Calls Today',
                    value: '$safeCount',
                    icon: Icons.verified_user_outlined,
                    color: AppColors.safeGreen,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SummaryStatCard(
                    label: 'Flagged / Escalated',
                    value: '$flaggedCount',
                    icon: Icons.gpp_maybe_outlined,
                    color: AppColors.dangerRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Recent Activity', onSeeAll: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              );
            }),
            const SizedBox(height: 12),
            ...logs.take(4).map((log) => _CallLogTile(log: log)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accentBlue,
        icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
        label: const Text('Simulate Incoming Call', style: TextStyle(color: Colors.white)),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LiveCallScreen()),
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgSurfaceElevated, AppColors.bgSurface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.safeGreen.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.safeGreen),
            ),
            child: const Icon(Icons.shield_rounded, color: AppColors.safeGreen, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.safeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SYSTEM ACTIVE',
                      style: TextStyle(
                        color: AppColors.safeGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Real-time voice analysis engine is monitoring calls',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        TextButton(onPressed: onSeeAll, child: const Text('See All')),
      ],
    );
  }
}

class _CallLogTile extends StatelessWidget {
  final CallLog log;
  const _CallLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(log.riskScore);
    final isSafe = log.verdict == CallVerdict.safe;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              isSafe ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.callerName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(log.callerNumber, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(log.riskScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(DateFormat('h:mm a').format(log.timestamp),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
