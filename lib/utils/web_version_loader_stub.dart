// Stub version loader for non-web platforms
Future<Map<String, String>> loadVersionFromJson() async {
  return {'version': '', 'buildNumber': ''};
}
