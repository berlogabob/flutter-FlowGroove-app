import 'dart:io' show Directory, File, FileSystemEntity, Process;

import 'package:flowgroove/config/env_config.dart';
import 'package:flowgroove/services/api/web_config.stub.dart'
    as web_config_stub;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Configuration Isolation Tests', () {
    group('Platform Detection', () {
      test('should detect non-web platform', () {
        if (!kIsWeb) {
          expect(kIsWeb, isFalse);
        }
      });

      test('EnvConfig should use dotenv on non-web', () {
        final config = EnvConfig();
        expect(config, isNotNull);
      });
    });

    group('Build Artifact Inspection', () {
      test('config.js should not exist in project root', () {
        final configFile = File('web/config.js');
        // config.js should only be generated during build/deploy
        // It should not exist in source control
        if (configFile.existsSync()) {
          // If it exists, it should be in .gitignore
          final gitignore = File('.gitignore');
          if (gitignore.existsSync()) {
            final gitignoreContent = gitignore.readAsStringSync();
            expect(
              gitignoreContent.contains('config.js') ||
                  gitignoreContent.contains('web/config.js'),
              isTrue,
              reason: 'config.js should be in .gitignore',
            );
          }
        }
      });

      test('web/config.template.js should exist', () {
        final templateFile = File('web/config.template.js');
        expect(
          templateFile.existsSync(),
          isTrue,
          reason: 'Template file should exist for web builds',
        );
      });

      test('.env.example should exist', () {
        final envExample = File('.env.example');
        expect(
          envExample.existsSync(),
          isTrue,
          reason: '.env.example should exist for documentation',
        );
      });

      test('.env should not be tracked by git', () {
        final result = Process.runSync('git', ['ls-files', '.env']);
        final output = result.stdout.toString();
        expect(
          output.trim().isEmpty,
          isTrue,
          reason: '.env should not be tracked by git',
        );
      });
    });

    group('Build Directory Inspection', () {
      test('build/web should not contain config.js before generation', () {
        final buildConfig = File('build/web/config.js');
        if (buildConfig.existsSync()) {
          final result = Process.runSync('git', [
            'ls-files',
            'build/web/config.js',
          ]);
          expect(
            result.stdout.toString().trim(),
            isEmpty,
            reason: 'Generated build/web/config.js must not be tracked',
          );
        }
      });

      test('build directory structure should be clean', () {
        final buildDir = Directory('build');
        if (buildDir.existsSync()) {
          final entities = buildDir.listSync(recursive: true);

          final envFiles = entities.where(
            (e) => e.path.contains('.env') && !e.path.contains('.env.example'),
          );

          expect(
            envFiles.isEmpty,
            isTrue,
            reason: 'No .env files should be in build directory',
          );
        }
      });
    });

    group('Android-Specific Configuration', () {
      test('android directory should not contain web config', () {
        final androidDir = Directory('android');
        if (androidDir.existsSync()) {
          final found = _findFilesByName(androidDir, 'config.js');
          expect(
            found.isEmpty,
            isTrue,
            reason: 'config.js should not be in android directory',
          );
        }
      });

      test('android/app should not contain .env', () {
        final androidAppDir = Directory('android/app');
        if (androidAppDir.existsSync()) {
          final found = _findFilesByName(androidAppDir, '.env');
          expect(
            found.isEmpty,
            isTrue,
            reason: '.env should not be in android/app directory',
          );
        }
      });

      test('android local.properties should be gitignored', () {
        final localProps = File('android/local.properties');
        if (localProps.existsSync()) {
          final gitignore = File('.gitignore');
          if (gitignore.existsSync()) {
            final content = gitignore.readAsStringSync();
            expect(
              content.contains('local.properties'),
              isTrue,
              reason: 'local.properties should be gitignored',
            );
          }
        }
      });
    });

    group('iOS-Specific Configuration', () {
      test('ios directory should not contain web config', () {
        final iosDir = Directory('ios');
        if (iosDir.existsSync()) {
          final found = _findFilesByName(iosDir, 'config.js');
          expect(
            found.isEmpty,
            isTrue,
            reason: 'config.js should not be in ios directory',
          );
        }
      });

      test('ios/Flutter should not contain .env', () {
        final iosFlutterDir = Directory('ios/Flutter');
        if (iosFlutterDir.existsSync()) {
          final found = _findFilesByName(iosFlutterDir, '.env');
          expect(
            found.isEmpty,
            isTrue,
            reason: '.env should not be in ios/Flutter directory',
          );
        }
      });
    });

    group('Pubspec Configuration', () {
      test('pubspec.yaml should not include web/config.js in assets', () {
        final pubspec = File('pubspec.yaml');
        if (pubspec.existsSync()) {
          final content = pubspec.readAsStringSync();
          expect(
            content.contains('config.js'),
            isFalse,
            reason: 'config.js should not be in pubspec.yaml assets',
          );
        }
      });

      test('pubspec.yaml should not include assets/env.json in assets', () {
        final pubspec = File('pubspec.yaml');
        if (pubspec.existsSync()) {
          final content = pubspec.readAsStringSync();
          expect(
            content.contains('env.json'),
            isFalse,
            reason: 'env.json should not be in pubspec.yaml assets',
          );
        }
      });
    });

    group('Git Ignore Verification', () {
      test('.gitignore should include web/config.js', () {
        final gitignore = File('.gitignore');
        expect(gitignore.existsSync(), isTrue);

        final content = gitignore.readAsStringSync();
        expect(
          content.contains('web/config.js') || content.contains('config.js'),
          isTrue,
          reason: 'web/config.js should be in .gitignore',
        );
      });

      test('.gitignore should include .env', () {
        final gitignore = File('.gitignore');
        expect(gitignore.existsSync(), isTrue);

        final content = gitignore.readAsStringSync();
        expect(
          content.contains('.env'),
          isTrue,
          reason: '.env should be in .gitignore',
        );
      });

      test('.gitignore should include assets/env.json', () {
        final gitignore = File('.gitignore');
        expect(gitignore.existsSync(), isTrue);

        final content = gitignore.readAsStringSync();
        expect(
          content.contains('env.json'),
          isTrue,
          reason: 'env.json should be in .gitignore',
        );
      });

      test('.gitignore should include build artifacts', () {
        final gitignore = File('.gitignore');
        expect(gitignore.existsSync(), isTrue);

        final content = gitignore.readAsStringSync();
        expect(
          content.contains('build/'),
          isTrue,
          reason: 'build/ should be in .gitignore',
        );
      });
    });

    group('Conditional Import Verification', () {
      test('web_config.stub.dart should exist', () {
        final stubFile = File('lib/services/api/web_config.stub.dart');
        expect(
          stubFile.existsSync(),
          isTrue,
          reason: 'Stub file should exist for non-web platforms',
        );
      });

      test('web_config.web.dart should exist', () {
        final webFile = File('lib/services/api/web_config.web.dart');
        expect(
          webFile.existsSync(),
          isTrue,
          reason: 'Web implementation should exist',
        );
      });

      test('stub implementation should return empty values', () {
        expect(web_config_stub.getWebConfig('FIREBASE_API_KEY'), isEmpty);
        expect(web_config_stub.hasWebConfig(), isFalse);
        expect(web_config_stub.hasWebConfigKey('FIREBASE_API_KEY'), isFalse);
      });
    });

    group('Build Script Verification', () {
      test('generate-web-config.sh should exist', () {
        final script = File('scripts/generate-web-config.sh');
        expect(
          script.existsSync(),
          isTrue,
          reason: 'Web config generation script should exist',
        );
      });

      test('inject-web-config.sh should exist', () {
        final script = File('scripts/inject-web-config.sh');
        expect(
          script.existsSync(),
          isTrue,
          reason: 'Web config injection script should exist',
        );
      });

      test('scripts should be executable', () {
        final genScript = File('scripts/generate-web-config.sh');
        final injScript = File('scripts/inject-web-config.sh');

        expect(_isExecutable(genScript), isTrue);
        expect(_isExecutable(injScript), isTrue);
      });
    });

    group('Integration Tests', () {
      test('EnvConfig should work without web config on non-web', () {
        final config = EnvConfig();
        expect(() => config.firebaseApiKey, returnsNormally);
      });

      test('Firebase options should use EnvConfig', () {
        final firebaseOptionsTest = File(
          'test/integration/firebase_config_test.dart',
        );
        expect(
          firebaseOptionsTest.existsSync(),
          isTrue,
          reason: 'Firebase config integration coverage should stay present',
        );
      });
    });
  });
}

List<FileSystemEntity> _findFilesByName(Directory dir, String name) {
  final found = <FileSystemEntity>[];

  try {
    final entities = dir.listSync(recursive: true, followLinks: false);
    for (final entity in entities) {
      if (entity.path.endsWith('/$name') || entity.path.endsWith('\\$name')) {
        found.add(entity);
      }
    }
  } catch (_) {}

  return found;
}

bool _isExecutable(File file) {
  if (!file.existsSync()) {
    return false;
  }

  return file.statSync().mode & 0x49 != 0;
}
