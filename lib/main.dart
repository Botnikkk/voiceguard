import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'package:voiceguard/models/recording_log.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(RecordingLogAdapter());
  Hive.registerAdapter(RecordingVerdictAdapter());

  await Hive.openBox<RecordingLog>("RecordingBox");

  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();

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
