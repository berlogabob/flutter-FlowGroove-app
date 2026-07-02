import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/mcp_api_key_service.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/snackbar.dart';
import '../../widgets/custom_app_bar.dart';

/// Manages per-user API keys for the MCP endpoint: mint (shown once), list, revoke,
/// plus a short "connect your AI" guide.
class ApiAccessScreen extends StatefulWidget {
  const ApiAccessScreen({super.key});

  /// Public MCP gateway endpoint.
  static const gatewayUrl =
      'https://us-central1-repsync-app-8685c.cloudfunctions.net/mcpGateway';

  @override
  State<ApiAccessScreen> createState() => _ApiAccessScreenState();
}

class _ApiAccessScreenState extends State<ApiAccessScreen> {
  final _service = McpApiKeyService();
  late Future<List<ApiKeyInfo>> _keys;

  @override
  void initState() {
    super.initState();
    _keys = _service.listKeys();
  }

  void _reload() => setState(() => _keys = _service.listKeys());

  Future<void> _createKey() async {
    final spec = await showModalBottomSheet<({String scope, String label})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateKeySheet(),
    );
    if (spec == null || !mounted) return;
    try {
      final token = await _service.createKey(scope: spec.scope, label: spec.label);
      if (!mounted) return;
      await _showTokenDialog(token);
      _reload();
    } catch (e) {
      _snack('Could not create key: $e');
    }
  }

  Future<void> _showTokenDialog(String token) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Your API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy it now — it is shown only once and cannot be recovered.',
            ),
            const SizedBox(height: 12),
            SelectableText(
              token,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (context.mounted) Navigator.pop(context);
              _snack('Key copied');
            },
            child: const Text('Copy & close'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(ApiKeyInfo key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke key'),
        content: Text('Revoke ${key.prefix}…? Any AI using it loses access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke',
                style: TextStyle(color: MonoPulseColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.revokeKey(key.id);
      _reload();
    } catch (e) {
      _snack('Could not revoke: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    showAppSnackBar(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(context, title: 'AI access (MCP)'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createKey,
        icon: const Icon(Icons.add),
        label: const Text('New key'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        children: [
          Text(
            'Connect your own AI to FlowGroove. Create a key, run the FlowGroove '
            'MCP server locally, and your assistant (Claude, ChatGPT, Gemini) can '
            'read and add songs. FlowGroove never uses your AI tokens.',
            style: MonoPulseTypography.bodyMedium.copyWith(
              color: MonoPulseColors.textSecondary,
            ),
          ),
          const SizedBox(height: MonoPulseSpacing.lg),
          const _GuideCard(gatewayUrl: ApiAccessScreen.gatewayUrl),
          const SizedBox(height: MonoPulseSpacing.lg),
          const Text('Your keys', style: MonoPulseTypography.titleMedium),
          const SizedBox(height: MonoPulseSpacing.sm),
          FutureBuilder<List<ApiKeyInfo>>(
            future: _keys,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(MonoPulseSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final keys = snap.data ?? const [];
              if (keys.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
                  child: Text('No keys yet. Create one to get started.'),
                );
              }
              return Column(
                children: [
                  for (final k in keys)
                    ListTile(
                      leading: Icon(
                        k.scope == 'write' ? Icons.edit : Icons.visibility,
                        color: MonoPulseColors.accentOrange,
                      ),
                      title: Text('${k.prefix}…  ·  ${k.scope}'),
                      subtitle: Text(k.label.isEmpty ? 'No label' : k.label),
                      trailing: IconButton(
                        tooltip: 'Revoke',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _revoke(k),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.gatewayUrl});
  final String gatewayUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MonoPulseSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How to connect', style: MonoPulseTypography.titleMedium),
          const SizedBox(height: 8),
          const Text('Gateway URL:'),
          SelectableText(
            gatewayUrl,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Run the MCP server (see mcp/README.md) with FLOWGROOVE_API_KEY set to '
            'your key and FLOWGROOVE_GATEWAY_URL set to the URL above, then add it '
            'to your AI client.',
          ),
        ],
      ),
    );
  }
}

class _CreateKeySheet extends StatefulWidget {
  const _CreateKeySheet();
  @override
  State<_CreateKeySheet> createState() => _CreateKeySheetState();
}

class _CreateKeySheetState extends State<_CreateKeySheet> {
  final _label = TextEditingController();
  String _scope = 'read';

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MonoPulseSpacing.lg,
        right: MonoPulseSpacing.lg,
        top: MonoPulseSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + MonoPulseSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New API key', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label (e.g. "Claude Desktop")',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'read',
                label: Text('Read only'),
                icon: Icon(Icons.visibility),
              ),
              ButtonSegment(
                value: 'write',
                label: Text('Read + write'),
                icon: Icon(Icons.edit),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                (scope: _scope, label: _label.text.trim()),
              ),
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }
}
