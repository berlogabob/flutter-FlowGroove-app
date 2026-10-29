import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/last_practice_context.dart';

class PracticeResumeCard extends ConsumerWidget {
  const PracticeResumeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastPracticeContextProvider).asData?.value;
    if (last == null) return const SizedBox.shrink();
    final subtitle = [
      last.title,
      if (last.bpm != null) '${last.bpm} BPM',
    ].join(' · ');
    void openSong() => context.pushNamed(
      'song',
      pathParameters: {'id': last.songId},
      queryParameters: {if (last.bandId != null) 'bandId': last.bandId},
    );
    return Semantics(
      onTap: openSong,
      label: 'Continue $subtitle',
      button: true,
      excludeSemantics: true,
      child: Card(
        child: ListTile(
          title: const Text('Continue'),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: openSong,
        ),
      ),
    );
  }
}
