import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> canCheckBiometrics() async {
    try {
      final can = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return can && supported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực để đăng nhập',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPassword, value: password);
  }

  static Future<({String email, String password})?> readCredentials() async {
    final email = await _storage.read(key: _kEmail);
    final password = await _storage.read(key: _kPassword);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
  }
}
