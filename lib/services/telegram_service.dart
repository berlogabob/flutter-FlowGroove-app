import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TelegramUser {

  TelegramUser({
    required this.id,
    this.firstName,
    this.lastName,
    this.username,
    this.photoUrl,
  });
  final int id;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? photoUrl;

  String get displayName => firstName ?? username ?? 'Telegram User';
}

class TelegramService {
  static const String botUsername = 'flowgroovebot';

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

  /// Client-side Bot API access is intentionally disabled.
  /// Route privileged Telegram actions through backend/functions.
  Future<bool> sendMessage(int chatId, String text) async {
    debugPrint(
      'TelegramService.sendMessage is disabled in the client. '
      'Use backend/functions for privileged bot actions.',
    );
    return false;
  }

  /// Client-side Bot API access is intentionally disabled.
  Future<bool> sendLinkRequest(int chatId, String userId) async {
    debugPrint(
      'TelegramService.sendLinkRequest is disabled in the client. '
      'Use backend/functions for privileged bot actions.',
    );
    return false;
  }

  /// Fetches user profile data from Telegram by username
  /// Note: This is limited - Telegram Bot API doesn't allow fetching other users' profiles
  /// We can only get data if the user has started a conversation with our bot
  ///
  /// Alternative: Use telegram_login package which requires verified domain
  ///
  /// Client-side Bot API access is intentionally disabled.
  Future<TelegramUser?> getUserByUsername(String username) async {
    debugPrint(
      'TelegramService.getUserByUsername is disabled in the client. '
      'Use backend/functions for privileged bot actions.',
    );
    return null;
  }

  /// Gets user profile photos
  /// Returns null if user has no photos or privacy is set
  Future<String?> getUserPhotoUrl(int userId) async {
    debugPrint(
      'TelegramService.getUserPhotoUrl is disabled in the client. '
      'Use backend/functions for privileged bot actions.',
    );
    return null;
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
