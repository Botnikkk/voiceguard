import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/call_log.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  CallVerdict? _filter;

  @override
  Widget build(BuildContext context) {
    final allLogs = CallLog.dummyList();
    final logs = _filter == null ? allLogs : allLogs.where((l) => l.verdict == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Call Logs')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  _filterChip('All', null),
                  const SizedBox(width: 8),
                  _filterChip('Safe', CallVerdict.safe),
                  const SizedBox(width: 8),
                  _filterChip('Flagged', CallVerdict.flagged),
                  const SizedBox(width: 8),
                  _filterChip('Escalated', CallVerdict.escalated),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _LogDetailTile(log: logs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, CallVerdict? verdict) {
    final selected = _filter == verdict;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = verdict),
      backgroundColor: AppColors.bgSurface,
      selectedColor: AppColors.accentBlue,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: BorderSide(color: selected ? AppColors.accentBlue : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _LogDetailTile extends StatelessWidget {
  final CallLog log;
  const _LogDetailTile({required this.log});

  String get _verdictLabel {
    switch (log.verdict) {
      case CallVerdict.safe:
        return 'SAFE';
      case CallVerdict.flagged:
        return 'FLAGGED';
      case CallVerdict.escalated:
        return 'ESCALATED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(log.riskScore);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(log.callerName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_verdictLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(log.callerNumber, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              _metaChip(Icons.percent_rounded, '${(log.riskScore * 100).toStringAsFixed(0)}% risk'),
              const SizedBox(width: 8),
              _metaChip(Icons.timer_outlined, '${log.duration.inMinutes}m ${log.duration.inSeconds % 60}s'),
              const Spacer(),
              Text(DateFormat('MMM d, h:mm a').format(log.timestamp),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
      ],
    );
  }
}
