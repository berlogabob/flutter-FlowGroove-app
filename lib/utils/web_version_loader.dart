// Web-specific version loader using dart:html
import 'dart:convert';
import 'dart:html' as html;

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
