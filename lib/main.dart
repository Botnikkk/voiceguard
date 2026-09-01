import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/services/call_detection_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'package:voiceguard/models/recording_log.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Hive for Flutter
  await Hive.initFlutter();

  // 3. Register your TypeAdapters (Crucial for custom objects!)
  // Ensure you generated the adapters for RecordingLog and RecordingVerdict
  Hive.registerAdapter(RecordingLogAdapter());
  Hive.registerAdapter(RecordingVerdictAdapter());

  // 4. Open the box once globally
  await Hive.openBox<RecordingLog>("RecordingBox");

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
