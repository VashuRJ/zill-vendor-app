import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _userTypeKey = 'user_type';

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // --- Token Management ---

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  // --- User Info ---

  Future<void> saveUserInfo({
    required int userId,
    required String username,
    required String userType,
  }) async {
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId.toString()),
      _storage.write(key: _usernameKey, value: username),
      _storage.write(key: _userTypeKey, value: userType),
    ]);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  Future<String?> getUserType() async {
    return await _storage.read(key: _userTypeKey);
  }

  Future<int?> getUserId() async {
    final id = await _storage.read(key: _userIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  // --- Clear All ---

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
