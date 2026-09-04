import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../call_analysis/screens/upload_audio_screen.dart';
// import '../../call_analysis/screens/live_call_screen.dart';
import '../../call_analysis/screens/mic_detection_screen.dart';

class ActionDrawerWidget extends StatelessWidget {
  const ActionDrawerWidget({super.key});

  Widget _buildAccuracyBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showActionDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Option 1: Upload Audio File -> UploadAudioScreen
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.safeGreen.withValues(alpha: 0.15),
                    child: const Icon(Icons.upload_file,
                        color: AppColors.safeGreen),
                  ),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Upload audio file',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      _buildAccuracyBadge('Most accurate', AppColors.safeGreen),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const UploadAudioScreen()),
                    );
                  },
                ),

                // Option 2: Intercept Live Call -> LiveCallInterceptScreen
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.15),
                    child:
                        const Icon(Icons.phone_in_talk, color: Colors.orange),
                  ),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Intercept live call',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      _buildAccuracyBadge('Moderately accurate', Colors.orange),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const Placeholder()),
                    );
                  },
                ),

                // Option 3: Detect Audio from Microphone -> MicDetectionScreen
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.dangerRed.withValues(alpha: 0.15),
                    child: const Icon(Icons.mic, color: AppColors.dangerRed),
                  ),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Detect audio from mic',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      _buildAccuracyBadge(
                          'Least accurate', AppColors.dangerRed),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const MicDetectionScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.accentBlue,
      onPressed: () => _showActionDrawer(context),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }
}
