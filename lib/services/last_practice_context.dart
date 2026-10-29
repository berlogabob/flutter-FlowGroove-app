import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastPracticeContext {
  const LastPracticeContext({
    required this.songId,
    required this.title,
    required this.updatedAt,
    this.bandId,
    this.bpm,
  });

  final String songId;
  final String? bandId;
  final String title;
  final int? bpm;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'bandId': bandId,
    'title': title,
    'bpm': bpm,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class LastPracticeContextStore {
  static const key = 'practice.last_context';

  Future<LastPracticeContext?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final songId = json['songId'] as String;
      final title = json['title'] as String;
      if (songId.trim().isEmpty || title.trim().isEmpty) return null;
      return LastPracticeContext(
        songId: songId,
        title: title,
        bandId: json['bandId'] as String?,
        bpm: json['bpm'] as int?,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LastPracticeContext context) async {
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(context.toJson()),
    );
  }
}

final lastPracticeContextProvider =
    FutureProvider.autoDispose<LastPracticeContext?>(
      (ref) => LastPracticeContextStore().load(),
    );
