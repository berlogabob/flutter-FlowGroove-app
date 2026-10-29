import 'setlist.dart';
import 'song.dart';

class TunerLaunchContext {
  const TunerLaunchContext({
    required this.song,
    this.setlist,
    this.setlistItemId,
    this.bandId,
    this.inferBandId = true,
    this.saveSong,
    this.saveSetlist,
  });
  final Song song;
  final Setlist? setlist;
  final String? setlistItemId;
  final String? bandId;
  final bool inferBandId;
  final Future<void> Function(Song song)? saveSong;
  final Future<void> Function(Setlist setlist)? saveSetlist;

  String? get initialPresetId {
    final itemId = setlistItemId;
    final currentSetlist = setlist;
    if (currentSetlist != null && itemId != null) {
      final override = currentSetlist.tuningPresetIdForItem(itemId);
      if (override != null && override.isNotEmpty) return override;
    }
    return song.defaultTuningPresetId;
  }

  String? get effectiveBandId {
    final overrideBandId = bandId?.trim();
    if (overrideBandId != null && overrideBandId.isNotEmpty) {
      return overrideBandId;
    }
    if (!inferBandId) return null;
    final setlistBandId = setlist?.bandId.trim();
    if (setlistBandId != null && setlistBandId.isNotEmpty) {
      return setlistBandId;
    }
    return song.bandId;
  }
}
