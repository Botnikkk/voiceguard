import 'package:flutter/material.dart' hide Placeholder;
import 'package:voiceguard/features/auth/screens/login_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../core/services/settings_service.dart';
import '../../../features/placeholder.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _logOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detection Sensitivity',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Higher sensitivity flags more calls for review',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12.5)),
                Row(
                  children: [
                    Expanded(
                        child: Slider(
                      value: SettingsService.instance.sensitivity.value,
                      min: 0,
                      max: 100,
                      onChanged: (val) {
                        setState(() {
                          SettingsService.instance.setSensitivity(val);
                        });
                      },
                    )),
                    const SizedBox(width: 8),
                    Text(
                      '${SettingsService.instance.sensitivity.value.toInt()}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('SECURITY'),
          _switchTile(
            title: 'Biometric App Lock',
            subtitle: 'Require Face ID / fingerprint to open the app',
            value: SettingsService.instance.biometricLock.value,
            onChanged: (v) {
              setState(() {
                SettingsService.instance.setBiometricLock(v);
              });
            },
          ),
          const SizedBox(height: 20),
          _sectionLabel('ACCOUNT'),
          _navTile(
              icon: Icons.person_outline,
              label: 'Analyst Profile',
              redirect: (BuildContext p1) {
                return const Placeholder(title: 'Analyst Profile');
              }),
          _navTile(
              icon: Icons.notifications_outlined,
              label: 'Notification Preferences',
              redirect: (BuildContext p1) {
                return const Placeholder(title: 'Notification Preferences');
              }),
          _navTile(
              icon: Icons.info_outline,
              label: 'About VoiceGuard AI',
              redirect: (BuildContext p1) {
                return const Placeholder(title: 'About VoiceGuard AI');
              }),
          CustomButton(
            label: 'LOG OUT',
            icon: Icons.logout_rounded,
            variant: ButtonVariant.danger,
            onPressed: () => _logOut(),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
      );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeTrackColor: AppColors.accentBlue,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14.5)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required Widget Function(BuildContext) redirect,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.textSecondary),
        title: Text(
          label,
          style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14.5),
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        // Pass the redirect function directly to the builder
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: redirect),
        ),
      ),
    );
  }
}
