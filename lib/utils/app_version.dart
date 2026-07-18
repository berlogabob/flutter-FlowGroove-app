import 'package:package_info_plus/package_info_plus.dart';

import 'web_version_loader_export.dart';

/// Resolves the displayed app version string ("1.2.3+45"), preferring the
/// web `version.json` (set at deploy time) and falling back to
/// `package_info_plus`, with a last-resort hardcoded fallback if both fail.
/// Shared by the Profile and Settings screens.
Future<String> loadAppVersionString() async {
  try {
    String version = '';
    String buildNumber = '';

    // On web, try to load version from version.json directly.
    try {
      final webVersion = await loadVersionFromJson();
      version = webVersion['version'] ?? '';
      buildNumber = webVersion['buildNumber'] ?? '';
    } catch (_) {
      // Ignore web loader errors
    }

    // If the web loader didn't work, use package_info_plus.
    if (version.isEmpty || buildNumber.isEmpty) {
      final packageInfo = await PackageInfo.fromPlatform();
      if (version.isEmpty) version = packageInfo.version;
      if (buildNumber.isEmpty) buildNumber = packageInfo.buildNumber;
    }

    if (buildNumber.isNotEmpty && buildNumber != '1') {
      return '$version+$buildNumber';
    }
    return version;
  } catch (e) {
    return '0.13.1+146';
  }
}
