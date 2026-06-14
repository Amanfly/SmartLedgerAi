import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return const SecurityService();
});

class SecurityService {
  const SecurityService();

  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();
  static const _pinKey = 'user_pin';
  static const _biometricKey = 'biometric_enabled';

  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin == pin;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
    await setBiometricEnabled(false);
  }

  Future<bool> canCheckBiometrics() async {
    return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
  }

  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricKey);
    return enabled == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access your ledger',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
