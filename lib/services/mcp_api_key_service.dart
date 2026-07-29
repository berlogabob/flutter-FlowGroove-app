import 'package:cloud_functions/cloud_functions.dart';

/// Metadata about an API key (never the token itself).
class ApiKeyInfo {
  ApiKeyInfo({
    required this.id,
    required this.scope,
    required this.label,
    required this.prefix,
    this.createdAt,
    this.lastUsedAt,
  });

  factory ApiKeyInfo.fromMap(Map<String, dynamic> m) => ApiKeyInfo(
    id: m['id'] as String,
    scope: m['scope'] as String? ?? 'read',
    label: m['label'] as String? ?? '',
    prefix: m['prefix'] as String? ?? 'fg_…',
    createdAt: (m['createdAt'] as num?)?.toInt(),
    lastUsedAt: (m['lastUsedAt'] as num?)?.toInt(),
  );

  final String id;
  final String scope;
  final String label;
  final String prefix;
  final int? createdAt;
  final int? lastUsedAt;
}

/// Callable wrappers for MCP API-key management (mint / list / revoke).
class McpApiKeyService {
  McpApiKeyService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Mints a key and returns the plaintext token **once**.
  Future<String> createKey({required String scope, String label = ''}) async {
    final result = await _functions
        .httpsCallable('createApiKey')
        .call<Map<String, dynamic>>({'scope': scope, 'label': label});
    return result.data['token'] as String;
  }

  Future<List<ApiKeyInfo>> listKeys() async {
    final result =
        await _functions.httpsCallable('listApiKeys').call<Map<String, dynamic>>();
    final raw = (result.data['keys'] as List?) ?? const [];
    return raw
        .map((e) => ApiKeyInfo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> revokeKey(String id) async {
    await _functions
        .httpsCallable('revokeApiKey')
        .call<Map<String, dynamic>>({'id': id});
  }
}
