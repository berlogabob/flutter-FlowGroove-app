// Web version loader using dart:html
// ignore: deprecated_member_use
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;

/// Load version information from JSON file (web only)
Future<Map<String, String>> loadVersionFromJson() async {
  try {
    final response = await html.HttpRequest.getString('version.json');
    final data = jsonDecode(response) as Map<String, dynamic>;
    return {
      'version': data['version'] as String? ?? '',
      'buildNumber': data['buildNumber'] as String? ?? '',
    };
  } catch (e) {
    return {'version': '', 'buildNumber': ''};
  }
}
