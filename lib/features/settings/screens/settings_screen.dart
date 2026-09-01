import 'package:flutter/material.dart';
import 'package:voiceguard/features/auth/screens/login_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _realTimeScanning = true;
  bool _autoEscalate = false;
  bool _biometricLock = true;
  double _sensitivity = 0.7;

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
          _sectionLabel('DETECTION'),
          _switchTile(
            title: 'Real-Time Scanning',
            subtitle: 'Continuously analyze active calls for cloned voices',
            value: _realTimeScanning,
            onChanged: (v) => setState(() => _realTimeScanning = v),
          ),
          _switchTile(
            title: 'Auto-Escalate High Risk',
            subtitle: 'Automatically notify fraud team above 85% risk',
            value: _autoEscalate,
            onChanged: (v) => setState(() => _autoEscalate = v),
          ),
          const SizedBox(height: 8),
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
                Slider(
                  value: _sensitivity,
                  activeColor: AppColors.accentCyan,
                  inactiveColor: AppColors.border,
                  onChanged: (v) => setState(() => _sensitivity = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('SECURITY'),
          _switchTile(
            title: 'Biometric App Lock',
            subtitle: 'Require Face ID / fingerprint to open the app',
            value: _biometricLock,
            onChanged: (v) => setState(() => _biometricLock = v),
          ),
          const SizedBox(height: 20),
          _sectionLabel('ACCOUNT'),
          _navTile(icon: Icons.person_outline, label: 'Analyst Profile'),
          _navTile(
              icon: Icons.notifications_outlined,
              label: 'Notification Preferences'),
          _navTile(icon: Icons.info_outline, label: 'About VoiceGuard AI'),
          CustomButton(
            label: 'LOG OUT',
            icon: Icons.logout_rounded,
            variant: ButtonVariant.danger,
            onPressed: () => _logOut(),
          ),
          const SizedBox(height: 40),
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

  Widget _navTile(
      {required IconData icon, required String label, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? AppColors.textSecondary),
        title: Text(label,
            style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14.5)),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: () {},
      ),
    );
  }
}
