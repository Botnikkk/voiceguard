import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:voiceguard/core/widgets/web_constraint.dart';

import './../../../core/data/database.dart';
import './../../../core/theme/app_colors.dart';
import './../../../models/recording_log.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  RecordingVerdict? _filter;

  final RecordingLogDatabase db = RecordingLogDatabase();

  @override
  Widget build(BuildContext context) {
    // 1. Listen directly to the Hive box, just like the Dashboard
    return ValueListenableBuilder<Box<RecordingLog>>(
      valueListenable: Hive.box<RecordingLog>("RecordingBox").listenable(),
      builder: (context, box, _) {
        // 2. Pull fresh data straight from the database
        final allLogs = box.values.toList().reversed.toList();
        final logs = _filter == null
            ? allLogs
            : allLogs.where((l) => l.verdict == _filter).toList();

        // 3. Delete directly from the box using the unique ID
        void deleteFunction(RecordingLog logToRemove) {
          // Find the exact Hive key for this log and delete it
          final keyToRemove = box.keys.firstWhere(
            (k) => box.get(k)?.id == logToRemove.id,
            orElse: () => null,
          );

          if (keyToRemove != null) {
            box.delete(
                keyToRemove); // Instant deletion, UI updates automatically
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Recordings')),
          body: WebConstraint(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All', null),
                          const SizedBox(width: 8),
                          _filterChip('Safe', RecordingVerdict.safe),
                          const SizedBox(width: 8),
                          _filterChip('Flagged', RecordingVerdict.flagged),
                          const SizedBox(width: 8),
                          _filterChip('Escalated', RecordingVerdict.escalated),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _LogDetailTile(
                        log: logs[i],
                        deleteFunction: (context) => deleteFunction(logs[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, RecordingVerdict? verdict) {
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
      side:
          BorderSide(color: selected ? AppColors.accentBlue : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _LogDetailTile extends StatelessWidget {
  final RecordingLog log;
  final Function(BuildContext)? deleteFunction;
  const _LogDetailTile({required this.log, required this.deleteFunction});

  String get _verdictLabel {
    switch (log.verdict) {
      case RecordingVerdict.safe:
        return 'SAFE';
      case RecordingVerdict.flagged:
        return 'FLAGGED';
      case RecordingVerdict.escalated:
        return 'ESCALATED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(log.riskScore);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Slidable(
        key: ValueKey(log.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.10,
          children: [
            SlidableAction(
              onPressed: deleteFunction,
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              icon: Icons.delete,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(log.recordingName,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_verdictLabel,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metaChip(Icons.percent_rounded,
                      '${(log.riskScore * 100).toStringAsFixed(0)}% risk'),
                  const SizedBox(width: 8),
                  _metaChip(Icons.timer_outlined,
                      '${log.duration.inMinutes}m ${log.duration.inSeconds % 60}s'),
                  const Spacer(),
                  Text(DateFormat('MMM d, h:mm a').format(log.timestamp),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11.5)),
      ],
    );
  }
}
