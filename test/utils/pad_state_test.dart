import 'package:flowgroove/utils/pad_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('padStateFor', () {
    test('returns idle when the section is neither queued nor playing', () {
      expect(padStateFor(sectionId: 'verse'), PadState.idle);
      expect(
        padStateFor(sectionId: 'verse', queuedId: 'chorus', playingId: 'intro'),
        PadState.idle,
      );
    });

    test('returns queued when only the queued id matches', () {
      expect(
        padStateFor(sectionId: 'verse', queuedId: 'verse', playingId: 'intro'),
        PadState.queued,
      );
    });

    test('returns playing when only the playing id matches', () {
      expect(
        padStateFor(sectionId: 'verse', queuedId: 'chorus', playingId: 'verse'),
        PadState.playing,
      );
    });

    test('returns queued when both queued and playing ids match', () {
      expect(
        padStateFor(sectionId: 'verse', queuedId: 'verse', playingId: 'verse'),
        PadState.queued,
      );
    });
  });

  group('padStateLabel', () {
    test('returns the idle label', () {
      expect(padStateLabel(PadState.idle), 'Idle');
    });

    test('returns the queued label', () {
      expect(padStateLabel(PadState.queued), 'Starts next bar');
    });

    test('returns the playing label', () {
      expect(padStateLabel(PadState.playing), 'Playing');
    });
  });
}
