import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:logger/logger.dart';

class SecurityService {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  final _logger = Logger();

  static const String _pinKey = 'user_pin';
  static const String _biometricsEnabledKey = 'biometrics_enabled';

  /// Saves the user's PIN securely.
  Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  /// Retrieves the stored PIN.
  Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  /// Clears the stored PIN (logout/lockout).
  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }

  /// Checks if biometrics are supported on the device.
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      _logger.e('Error checking biometrics availability', error: e);
      return false;
    }
  }

  /// Attempts to authenticate using biometrics.
  Future<bool> authenticateWithBiometrics({
    required String reason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Autenticação Biométrica',
            cancelButton: 'Cancelar',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancelar',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      _logger.e('Biometric authentication error', error: e);
      return false;
    }
  }

  /// Saves whether biometrics are enabled by the user.
  Future<void> setBiometricsEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricsEnabledKey,
      value: enabled.toString(),
    );
  }

  /// Checks if biometrics are enabled in app settings.
  Future<bool> isBiometricsEnabled() async {
    final value = await _storage.read(key: _biometricsEnabledKey);
    return value == 'true';
  }
}
