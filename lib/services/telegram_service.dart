import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class TelegramUser {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;

  TelegramUser({
    required this.id,
    this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
  });

  String get displayName => firstName ?? username ?? 'Telegram User';
}

class TelegramService {
  static String get botToken => dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '';
  static const String botUsername = 'repsyncbot';

  /// Opens Telegram chat with the bot and sends /link command
  Future<bool> openBotChat(String? userId) async {
    try {
      final startParam = userId != null ? 'link_$userId' : 'link';

      // Try native Telegram app first with tg:// scheme
      final nativeUrl = Uri.parse(
        'tg://resolve?domain=$botUsername&start=$startParam',
      );

      if (await canLaunchUrl(nativeUrl)) {
        return await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
      }

      // Fallback to web/Telegram TV
      final webUrl = Uri.parse('https://t.me/$botUsername?start=$startParam');
      if (await canLaunchUrl(webUrl)) {
        return await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }

      return false;
    } catch (e) {
      debugPrint('Error opening Telegram: $e');
      return false;
    }
  }

  /// Sends a message to a Telegram user
  Future<bool> sendMessage(int chatId, String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.telegram.org/bot$botToken/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'chat_id': chatId, 'text': text}),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram send message error: $e');
      return false;
    }
  }

  /// Sends inline keyboard with Yes/No buttons
  Future<bool> sendLinkRequest(int chatId, String userId) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.telegram.org/bot$botToken/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'chat_id': chatId,
              'text':
                  'Do you want to link your Telegram profile to RepSync app?',
              'reply_markup': {
                'inline_keyboard': [
                  [
                    {
                      'text': '✅ Yes, link my profile',
                      'callback_data': 'link_$userId',
                    },
                    {'text': '❌ No', 'callback_data': 'cancel_link'},
                  ],
                ],
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Telegram send keyboard error: $e');
      return false;
    }
  }

  /// Fetches user profile data from Telegram by username
  /// Note: This is limited - Telegram Bot API doesn't allow fetching other users' profiles
  /// We can only get data if the user has started a conversation with our bot
  ///
  /// Alternative: Use telegram_login package which requires verified domain
  ///
  /// For now, we'll use a workaround - check if username exists via bot
  Future<TelegramUser?> getUserByUsername(String username) async {
    try {
      // First, try to get chat ID by username
      // This works if user has ever interacted with the bot
      final response = await http
          .get(
            Uri.parse(
              'https://api.telegram.org/bot$botToken/getChat?chat_id=@${username.replaceAll('@', '')}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true && data['result'] != null) {
          final chat = data['result'];
          return TelegramUser(
            id: chat['id'] as int,
            firstName: chat['first_name'] as String?,
            lastName: chat['last_name'] as String?,
            username: chat['username'] as String?,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Telegram API error: $e');
      return null;
    }
  }

  /// Gets user profile photos
  /// Returns null if user has no photos or privacy is set
  Future<String?> getUserPhotoUrl(int userId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.telegram.org/bot$botToken/getUserProfilePhotos?user_id=$userId&limit=1',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true && data['result'] != null) {
          final photos = data['result']['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            // Get the smallest photo (index 0 has smallest)
            final photo = photos[0] as List;
            if (photo.isNotEmpty) {
              final fileId = photo[0]['file_id'];
              // Now get the file path
              return await _getFilePath(fileId);
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Telegram get photo error: $e');
      return null;
    }
  }

  Future<String?> _getFilePath(String fileId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.telegram.org/bot$botToken/getFile?file_id=$fileId',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true && data['result'] != null) {
          final filePath = data['result']['file_path'];
          return 'https://api.telegram.org/file/bot$botToken/$filePath';
        }
      }
      return null;
    } catch (e) {
      debugPrint('Telegram get file error: $e');
      return null;
    }
  }

  /// Downloads photo to local storage
  Future<File?> downloadPhoto(String url, String savePath) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Telegram download photo error: $e');
      return null;
    }
  }
}
