import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _keySensitivity = 'detection_sensitivity';
  static const String _keyBiometric = 'biometric_lock';
  
  late SharedPreferences _prefs;

  // ValueNotifiers let any widget or service listen to changes reactively
  final ValueNotifier<double> sensitivity = ValueNotifier<double>(70.0);
  final ValueNotifier<bool> biometricLock = ValueNotifier<bool>(true);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    sensitivity.value = _prefs.getDouble(_keySensitivity) ?? 70.0;
    // Defaulting to true for security, change to false if you prefer
    biometricLock.value = _prefs.getBool(_keyBiometric) ?? true; 
  }

  Future<void> setSensitivity(double value) async {
    sensitivity.value = value;
    await _prefs.setDouble(_keySensitivity, value);
  }

  Future<void> setBiometricLock(bool value) async {
    biometricLock.value = value;
    await _prefs.setBool(_keyBiometric, value);
  }
}