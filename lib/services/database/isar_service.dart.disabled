import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Isar database service.
///
/// Provides a singleton instance of Isar database with:
/// - Platform-specific configuration
/// - Collection schema management
/// - CRUD operations helper
///
/// Note: Isar doesn't support web, so this service is for mobile/desktop only.
/// For web, continue using Hive or implement a web-specific storage.
class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  static IsarService get instance => _instance;

  Isar? _isar;

  /// Initialize Isar database.
  ///
  /// Call this during app initialization.
  ///
  /// Example:
  /// ```dart
  /// await IsarService().init();
  /// ```
  Future<void> init() async {
    if (_isar != null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [], // Start with empty schema, add collections as migrated
        directory: dir.path,
        inspector: kDebugMode,
      );
      debugPrint('✅ Isar initialized at ${dir.path}');
    } catch (e, stackTrace) {
      debugPrint('❌ Isar initialization failed: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  /// Get the Isar instance.
  ///
  /// Throws if not initialized. Call [init] first.
  Isar get db {
    if (_isar == null) {
      throw StateError(
        'Isar not initialized. Call IsarService().init() first.',
      );
    }
    return _isar!;
  }

  /// Close the database.
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
    debugPrint('🗑️ Isar closed');
  }

  /// Clear all data (for testing).
  ///
  /// ⚠️ WARNING: This deletes ALL data!
  Future<void> clearAll() async {
    await db.writeTxn(() async {
      await db.clear();
    });
    debugPrint('🗑️ Isar cleared all data');
  }

  /// Get database size in bytes.
  Future<int> get size async {
    return await db.calculateSize();
  }

  /// Export database to file (for backup).
  Future<void> exportBackup(String filePath) async {
    await db.export(filePath: filePath);
    debugPrint('💾 Isar backup exported to $filePath');
  }
}

/// Global instance for easy access.
final isar = IsarService();
