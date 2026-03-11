import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data.
///
/// This service provides a secure way to store sensitive information like:
/// - Auth tokens
/// - API keys
/// - User credentials
///
/// Uses platform-specific secure storage:
/// - iOS: Keychain
/// - Android: Encrypted SharedPreferences
/// - Web: localStorage (fallback, less secure)
/// - macOS: Keychain
/// - Windows: Windows Credential Manager
/// - Linux: libsecret
class SecureStorageService {
  final FlutterSecureStorage _storage;

  /// Keys for secure storage
  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          // Configure options for better security
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  /// Write a value to secure storage.
  ///
  /// [key]: The storage key
  /// [value]: The value to store
  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
      debugPrint('✅ SecureStorage: Wrote $key');
    } catch (e) {
      debugPrint('❌ SecureStorage: Failed to write $key - $e');
      rethrow;
    }
  }

  /// Read a value from secure storage.
  ///
  /// [key]: The storage key
  /// Returns the value or null if not found
  Future<String?> read({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      debugPrint('📖 SecureStorage: Read $key = ${value != null ? '***' : 'null'}');
      return value;
    } catch (e) {
      debugPrint('❌ SecureStorage: Failed to read $key - $e');
      return null;
    }
  }

  /// Delete a value from secure storage.
  ///
  /// [key]: The storage key
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
      debugPrint('🗑️ SecureStorage: Deleted $key');
    } catch (e) {
      debugPrint('❌ SecureStorage: Failed to delete $key - $e');
      rethrow;
    }
  }

  /// Delete all values from secure storage.
  ///
  /// Use with caution!
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('🗑️ SecureStorage: Deleted ALL');
    } catch (e) {
      debugPrint('❌ SecureStorage: Failed to delete all - $e');
      rethrow;
    }
  }

  /// Check if a key exists in secure storage.
  ///
  /// [key]: The storage key
  /// Returns true if the key exists
  Future<bool> containsKey({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e) {
      debugPrint('❌ SecureStorage: Failed to check $key - $e');
      return false;
    }
  }

  // ============================================
  // AUTH TOKEN METHODS
  // ============================================

  /// Save auth token securely.
  Future<void> saveAuthToken(String token) async {
    await write(key: _authTokenKey, value: token);
  }

  /// Get auth token from secure storage.
  Future<String?> getAuthToken() async {
    return await read(key: _authTokenKey);
  }

  /// Delete auth token from secure storage.
  Future<void> deleteAuthToken() async {
    await delete(key: _authTokenKey);
  }

  /// Save refresh token securely.
  Future<void> saveRefreshToken(String token) async {
    await write(key: _refreshTokenKey, value: token);
  }

  /// Get refresh token from secure storage.
  Future<String?> getRefreshToken() async {
    return await read(key: _refreshTokenKey);
  }

  /// Delete refresh token from secure storage.
  Future<void> deleteRefreshToken() async {
    await delete(key: _refreshTokenKey);
  }

  /// Save user ID securely.
  Future<void> saveUserId(String userId) async {
    await write(key: _userIdKey, value: userId);
  }

  /// Get user ID from secure storage.
  Future<String?> getUserId() async {
    return await read(key: _userIdKey);
  }

  /// Delete user ID from secure storage.
  Future<void> deleteUserId() async {
    await delete(key: _userIdKey);
  }

  /// Clear all auth-related data.
  Future<void> clearAuthData() async {
    await deleteAuthToken();
    await deleteRefreshToken();
    await deleteUserId();
    debugPrint('✅ SecureStorage: Cleared all auth data');
  }

  /// Get all stored keys (for debugging).
  Future<List<String>> getAllKeys() async {
    // Note: FlutterSecureStorage doesn't provide a way to list all keys
    // This is a limitation of the secure storage API
    return [
      _authTokenKey,
      _refreshTokenKey,
      _userIdKey,
    ];
  }
}

/// Global instance for easy access.
///
/// Alternatively, you can use Riverpod to provide this service.
final secureStorage = SecureStorageService();
