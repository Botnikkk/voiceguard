import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/network/api_config.dart';
import '../../../core/data/database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/web_constraint.dart';
import '../../../models/recording_log.dart';
import '../widgets/action_drawer.dart';
import '../../logs/screens/logs_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../widgets/call_summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final RecordingLogDatabase db = RecordingLogDatabase();

  // State variables for connection status
  bool? _isBackendConnected;
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    db.createInitialData();
    _checkBackendStatus(); // Ping backend when dashboard opens
  }

  /// Creates a temporary connection to check if the backend is alive,
  /// then immediately closes it so it doesn't hog the WebSocket.
  Future<void> _checkBackendStatus() async {
    if (!mounted) return;
    setState(() => _isCheckingStatus = true);

    bool isConnected = false;
    try {
      final channel =
          WebSocketChannel.connect(Uri.parse(ApiConfig.voiceAnalysisWsUrl));
      // Wait for the connection to establish, timing out after 3 seconds
      await channel.ready.timeout(const Duration(seconds: 3));
      isConnected = true;

      // Immediately release the connection
      channel.sink.close();
    } catch (e) {
      isConnected = false;
    }

    if (mounted) {
      setState(() {
        _isBackendConnected = isConnected;
        _isCheckingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<RecordingLog>>(
      valueListenable: Hive.box<RecordingLog>("RecordingBox").listenable(),
      builder: (context, box, _) {
        final logs = box.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final safeCount =
            logs.where((l) => l.verdict == RecordingVerdict.safe).length;
        final flaggedCount =
            logs.where((l) => l.verdict != RecordingVerdict.safe).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('VOICEGUARD'),
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
          body: WebConstraint(
            child: SafeArea(
              // Wrap with RefreshIndicator for manual pull-to-refresh
              child: RefreshIndicator(
                onRefresh: _checkBackendStatus,
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Ensures it can be pulled even if list is short
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
                    _buildSectionHeader(
                      context,
                      'Recent Activity',
                      onSeeAll: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (logs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'No recordings yet',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...logs.take(4).map((log) => _CallLogTile(log: log)),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: const ActionDrawerWidget(),
        );
      },
    );
  }

  Widget _buildSystemStatusCard(BuildContext context) {
    final bool isConnected = _isBackendConnected ?? false;
    final bool isLoading = _isCheckingStatus && _isBackendConnected == null;

    final Color statusColor = isLoading
        ? Colors.orange
        : (isConnected ? AppColors.safeGreen : AppColors.dangerRed);

    final String title = isLoading
        ? 'CHECKING STATUS'
        : (isConnected ? 'SYSTEM ACTIVE' : 'SERVER OFFLINE');

    final String subtitle = isLoading
        ? 'Pinging backend server...'
        : (isConnected
            ? 'Real-time voice analysis engine is ready'
            : 'Cannot connect to analysis backend');

    final IconData icon = isLoading
        ? Icons.sync
        : (isConnected ? Icons.shield_rounded : Icons.cloud_off_rounded);

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
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.12),
              border: Border.all(color: statusColor),
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 26,
            ),
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
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          // ADDED: Dedicated refresh button for Web/Desktop mouse users
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: statusColor,
            tooltip: 'Refresh Status',
            onPressed: _isCheckingStatus ? null : _checkBackendStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onSeeAll,
  }) {
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
  final RecordingLog log;
  const _CallLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(log.riskScore);
    final isSafe = log.verdict == RecordingVerdict.safe;

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
            child: Text(
              log.recordingName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(log.riskScore * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('h:mm a').format(log.timestamp),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
