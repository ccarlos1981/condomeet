import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class SecurityService {
  final FlutterSecureStorage _storage;
  final _auth = LocalAuthentication();
  final _logger = Logger();
  bool _usesFallback = false;

  SecurityService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _pinKey = 'user_pin_hash';
  static const String _biometricsEnabledKey = 'biometrics_enabled';

  // --- Safe storage wrappers with SharedPreferences fallback ---

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      _logger.w('SecureStorage write failed, using SharedPreferences fallback: $e');
      _usesFallback = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('_secure_$key', value);
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      if (_usesFallback) throw Exception('Already in fallback mode');
      return await _storage.read(key: key);
    } catch (e) {
      _usesFallback = true;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('_secure_$key');
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('_secure_$key');
    }
  }

  // --- PIN Methods ---

  /// Saves a hashed version of the user's PIN.
  Future<void> savePin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await _safeWrite(_pinKey, hash);
  }

  /// Verifies if a PIN matches the stored hash.
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _safeRead(_pinKey);
    if (storedHash == null) return false;
    final inputHash = sha256.convert(utf8.encode(pin)).toString();
    return storedHash == inputHash;
  }

  /// Retrieves the stored PIN hash.
  @Deprecated('Use verifyPin instead')
  Future<String?> getPin() async {
    return await _safeRead(_pinKey);
  }

  /// Clears the stored PIN (logout/lockout).
  Future<void> clearPin() async {
    await _safeDelete(_pinKey);
  }

  // --- Biometrics ---

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
    await _safeWrite(_biometricsEnabledKey, enabled.toString());
  }

  /// Checks if biometrics are enabled in app settings.
  Future<bool> isBiometricsEnabled() async {
    final value = await _safeRead(_biometricsEnabledKey);
    return value == 'true';
  }
}
