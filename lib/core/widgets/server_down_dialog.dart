// lib/core/widgets/server_down_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shows a blocking "server is down" prompt. Guarded so rapid repeated
/// calls don't stack multiple dialogs. [onDismissed] fires once the user
/// taps OK — callers use it to exit the screen so the feature can't be
/// used against a connection that's confirmed down.
void showServerDownDialog(BuildContext context, {VoidCallback? onDismissed}) {
  if (!context.mounted || _ServerDownDialogGuard.isShowing) return;
  _ServerDownDialogGuard.isShowing = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.bgSurfaceElevated,
      icon: const Icon(Icons.cloud_off_rounded,
          color: AppColors.dangerRed, size: 36),
      title: const Text('Server Unavailable',
          style: TextStyle(color: AppColors.textPrimary)),
      content: const Text(
        "We couldn't reach the detection server. Please try again later.",
        style: TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  ).then((_) {
    _ServerDownDialogGuard.isShowing = false;
    onDismissed?.call();
  });
}

class _ServerDownDialogGuard {
  static bool isShowing = false;
}
