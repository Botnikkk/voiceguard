import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/call_detection_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: VoiceGuardApp()));
}

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

class VoiceGuardApp extends StatefulWidget {
  const VoiceGuardApp({super.key});

  @override
  State<VoiceGuardApp> createState() => _VoiceGuardAppState();
}

class _VoiceGuardAppState extends State<VoiceGuardApp> {
  @override
  void initState() {
    super.initState();

    CallDetectionService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'VoiceGuard AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const LoginScreen(),
    );
  }
}
