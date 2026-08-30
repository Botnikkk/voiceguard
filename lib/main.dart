import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: VoiceGuardApp()));
}

class VoiceGuardApp extends StatefulWidget {
  const VoiceGuardApp({super.key});

  @override
  State<VoiceGuardApp> createState() => _VoiceGuardAppState();
}

class _VoiceGuardAppState extends State<VoiceGuardApp> {

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'VoiceGuard AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      home: Placeholder(),
    );
  }
}

