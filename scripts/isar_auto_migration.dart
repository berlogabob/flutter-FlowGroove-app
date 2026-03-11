#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';

/// ISAR Auto-Migration Script
/// 
/// This script migrates Hive models to Isar automatically.
/// 
/// Usage: dart scripts/isar_auto_migration.dart
/// 
/// What it does:
/// 1. Scans lib/models/ for Dart files
/// 2. Parses Hive annotations
/// 3. Generates Isar equivalents
/// 4. Backs up original files
/// 5. Writes migrated files
/// 
/// Run build_runner after: dart run build_runner build --delete-conflicting-outputs

const String modelsDir = 'lib/models/';
const String backupDir = 'lib/models/.backup/';

// Models to skip (already migrated or special cases)
const List<String> skipModels = ['link.dart'];

// Complex models that need manual review
const List<String> complexModels = ['song.dart', 'setlist.dart', 'band.dart'];

void main() async {
  print('🗄️  ISAR Auto-Migration Script');
  print('=' * 50);
  
  // Create backup directory
  await Directory(backupDir).create(recursive: true);
  
  // Get all Dart files in models directory
  final modelsDirectory = Directory(modelsDir);
  if (!await modelsDirectory.exists()) {
    print('❌ Models directory not found: $modelsDir');
    exit(1);
  }
  
  final dartFiles = await modelsDirectory
      .list()
      .where((entity) => 
          entity.path.endsWith('.dart') && 
          !entity.path.endsWith('.g.dart') &&
          !skipModels.any((skip) => entity.path.endsWith(skip)))
      .toList();
  
  print('📁 Found ${dartFiles.length} models to migrate\n');
  
  int successCount = 0;
  int errorCount = 0;
  
  for (final file in dartFiles) {
    final fileName = file.path.split('/').last;
    print('📝 Migrating: $fileName');
    
    try {
      // Backup original
      await backupFile(file.path);
      
      // Read and migrate
      final content = await File(file.path).readAsString();
      final migrated = migrateModel(content, fileName);
      
      // Write migrated version
      await File(file.path).writeAsString(migrated);
      
      print('✅ Migrated: $fileName');
      successCount++;
    } catch (e) {
      print('❌ Error migrating $fileName: $e');
      errorCount++;
    }
    print('');
  }
  
  print('=' * 50);
  print('📊 Migration Summary:');
  print('  ✅ Success: $successCount');
  print('  ❌ Errors: $errorCount');
  print('  📁 Total: ${successCount + errorCount}');
  print('');
  
  if (errorCount > 0) {
    print('⚠️  Some files failed. Check errors above.');
    print('💡 You can restore from backup: $backupDir');
  }
  
  print('');
  print('🎯 Next Steps:');
  print('  1. Review migrated files');
  print('  2. Run: dart run build_runner build --delete-conflicting-outputs');
  print('  3. Test: flutter build web');
  print('  4. Migrate complex models manually: ${complexModels.join(", ")}');
  print('');
}

Future<void> backupFile(String filePath) async {
  final fileName = filePath.split('/').last;
  final backupPath = '$backupDir$fileName';
  await File(filePath).copy(backupPath);
  print('   💾 Backed up to: $backupPath');
}

String migrateModel(String content, String fileName) {
  var migrated = content;
  
  // Step 1: Add Isar import
  if (!migrated.contains('import \'package:isar/isar.dart\';')) {
    migrated = migrated.replaceFirst(
      'import \'package:json_annotation/json_annotation.dart\';',
      'import \'package:isar/isar.dart\';\nimport \'package:json_annotation/json_annotation.dart\';',
    );
  }
  
  // Step 2: Add @collection annotation before class
  migrated = migrated.replaceAllMapped(
    RegExp(r'^class (\w+) \{', multiLine: true),
    (match) => '@collection\nclass ${match.group(1)} {',
  );
  
  // Step 3: Replace final String id with Id id = Isar.autoIncrement
  migrated = migrated.replaceAll(
    RegExp(r'final String id;'),
    'Id id = Isar.autoIncrement;',
  );
  
  // Step 4: Replace final int id with Id id = Isar.autoIncrement
  migrated = migrated.replaceAll(
    RegExp(r'final int id;'),
    'Id id = Isar.autoIncrement;',
  );
  
  // Step 5: Remove 'final' from other fields and add defaults
  migrated = migrated.replaceAllMapped(
    RegExp(r'final String (\w+);'),
    (match) => 'String ${match.group(1)} = \'\';',
  );
  
  migrated = migrated.replaceAllMapped(
    RegExp(r'final int (\w+);'),
    (match) => 'int ${match.group(1)} = 0;',
  );
  
  migrated = migrated.replaceAllMapped(
    RegExp(r'final bool (\w+);'),
    (match) => 'bool ${match.group(1)} = false;',
  );
  
  migrated = migrated.replaceAllMapped(
    RegExp(r'final double (\w+);'),
    (match) => 'double ${match.group(1)} = 0.0;',
  );
  
  // Step 6: Add @Index() to fields that look like they should be indexed
  migrated = migrated.replaceAllMapped(
    RegExp(r'  String (id|name|type|email|uid) =', multiLine: true),
    (match) => '  @Index()\n  String ${match.group(1)} =',
  );
  
  // Step 7: Update constructor to have default values
  // This is complex - we'll add a fromMap/toMap method instead
  if (!migrated.contains('fromMap')) {
    final className = fileName.replaceAll('.dart', '');
    final fromMapMethod = '''

  /// Create from map for Isar compatibility.
  factory ${className}Id.fromMap(Map<String, dynamic> data) => ${className}Id(
    id: data['id'] as int? ?? Isar.autoIncrement,
  );

  /// Convert to map for Isar compatibility.
  Map<String, dynamic> toMap() => {
    'id': id,
  };
''';
    
    // Add before the closing brace of the class
    migrated = migrated.replaceFirst('}', fromMapMethod + '}');
  }
  
  // Step 8: Add Isar.autoIncrement default to id parameter in constructor
  migrated = migrated.replaceAll(
    RegExp(r'(\s+)(this\.id|id:)(\s*)(=)?'),
    '\$1\$2\$3= Isar.autoIncrement',
  );
  
  return migrated;
}
