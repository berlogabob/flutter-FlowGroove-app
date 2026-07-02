import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/snackbar.dart';

/// Curated share sheet: Copy / Share via… / Email / Telegram / WhatsApp.
///
/// One home for the share modal that used to be inlined per-screen. The
/// explicit WhatsApp/Telegram tiles use web links (`wa.me` / `t.me`) so they
/// work on web too, where the native `share_plus` sheet may be unavailable.
void showShareSheet(BuildContext context, String message, {String? subject}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy to clipboard'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(sheetContext);
              showAppSnackBar(sheetContext, 'Copied to clipboard!');
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share via...'),
            onTap: () {
              Navigator.pop(sheetContext);
              // ponytail: web/desktop may no-op; explicit tiles below cover it.
              SharePlus.instance
                  .share(ShareParams(text: message, subject: subject))
                  .ignore();
            },
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            onTap: () {
              Navigator.pop(sheetContext);
              final emailUri = Uri(
                scheme: 'mailto',
                queryParameters: {
                  'subject': ?subject,
                  'body': message,
                },
              );
              launchUrl(emailUri);
            },
          ),
          ListTile(
            leading: const Icon(Icons.telegram),
            title: const Text('Telegram'),
            onTap: () {
              Navigator.pop(sheetContext);
              final telegramUri = Uri.parse(
                'https://t.me/share/url?url=${Uri.encodeComponent(message)}',
              );
              launchUrl(telegramUri, mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('WhatsApp'),
            onTap: () {
              Navigator.pop(sheetContext);
              final whatsappUri = Uri.parse(
                'https://wa.me/?text=${Uri.encodeComponent(message)}',
              );
              launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    ),
  );
}
