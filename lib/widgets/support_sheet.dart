import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/telegram_service.dart';

/// Support contact menu. One-way links only — no backend, no cost.
/// Extend by adding another ListTile (e.g. Email, GitHub issue).
void showSupportSheet(BuildContext context, {String? appVersion}) {
  final greeting =
      'Hi FlowGroove support 👋'
      '${appVersion != null ? '\n\n(App version: $appVersion)' : ''}\n\n';

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.telegram),
            title: const Text('Telegram'),
            subtitle: const Text('Chat with our support bot'),
            onTap: () {
              Navigator.pop(sheetContext);
              launchUrl(
                Uri.parse(TelegramService.botLink()),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('WhatsApp'),
            subtitle: const Text('Message us on WhatsApp'),
            onTap: () {
              Navigator.pop(sheetContext);
              launchUrl(
                Uri.parse(
                  'https://wa.me/351913436987?text=${Uri.encodeComponent(greeting)}',
                ),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
    ),
  );
}
