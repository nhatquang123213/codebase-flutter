import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}

/// Tokens live in Keychain / Keystore — never in SharedPreferences.
/// The access token is cached in memory because it is read on every request.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;
  String? _accessToken;
  bool _isLoaded = false;

  @override
  Future<String?> readAccessToken() async {
    if (!_isLoaded) {
      _accessToken = await _storage.read(key: _accessKey);
      _isLoaded = true;
    }
    return _accessToken;
  }

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    _accessToken = accessToken;
    _isLoaded = true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    _accessToken = null;
    _isLoaded = true;
  }
}
