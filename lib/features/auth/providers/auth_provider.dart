import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

enum AuthStatus { idle, loading, authenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  const AuthState({this.status = AuthStatus.idle, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(status: status ?? this.status, errorMessage: errorMessage);
  }
}

/// Auth controller. Login is still mocked,
/// fingerprint / Face ID prompt via `local_auth`.
class AuthController extends StateNotifier<AuthState> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthController() : super(const AuthState());

  Future<void> login(String userId, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    await Future.delayed(const Duration(milliseconds: 900)); // mock network

    if (userId.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Please enter both User ID and Password.',
      );
      return;
    }

    // Dummy success path for demo purposes — replace with your real API call.
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  /// Triggers the phone's native biometric prompt.
  Future<void> loginWithBiometrics() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'This device has no biometric hardware configured.',
        );
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access VoiceGuard AI',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN/pattern fallback too
          stickyAuth: true, // survives brief app backgrounding mid-prompt
        ),
      );

      if (didAuthenticate) {
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(status: AuthStatus.idle);
      }
    } on PlatformException catch (e) {
      String message = 'Biometric authentication failed.';
      if (e.code == auth_error.notAvailable) {
        message = 'Biometric authentication is not available on this device.';
      } else if (e.code == auth_error.notEnrolled) {
        message =
            'No fingerprint or face enrolled. Add one in device settings.';
      } else if (e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        message = 'Too many attempts. Biometric login is temporarily locked.';
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: message);
    }
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(),
);
