import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the bearer token lives between app launches.
///
/// ponytail: an interface with one shared_preferences implementation. Tests
/// use [MemoryTokenStore] so they never touch a platform channel, and swapping
/// in flutter_secure_storage later means writing a new class, not changing
/// AuthService.
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// The real store. shared_preferences works on web, mobile and desktop from one
/// code path, like the rest of this app.
class SharedPrefsTokenStore implements TokenStore {
  static const _key = 'ligtasalert.auth_token';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// The production store. The bearer token is the only thing standing between a
/// rescuee and their alerts, so it goes in the platform keychain (iOS
/// Keychain, Android Keystore, Windows Credential Vault) rather than the
/// plaintext shared preferences a campus phone may share.
///
/// ponytail: drop SharedPrefsTokenStore entirely once every platform is on
/// secure storage. It stays here as the fallback for the web, which has no
/// keychain and where the browser already isolates per-origin storage.
class SecurePrefsTokenStore implements TokenStore {
  SecurePrefsTokenStore(this._store);

  final FlutterSecureStorage _store;

  static const _key = 'ligtasalert.auth_token';

  @override
  Future<String?> read() => _store.read(key: _key);

  @override
  Future<void> write(String token) => _store.write(key: _key, value: token);

  @override
  Future<void> clear() => _store.delete(key: _key);
}

/// Test double. Starts empty unless seeded.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}