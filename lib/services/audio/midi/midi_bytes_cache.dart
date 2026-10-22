import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

const midiBytesBoxName = 'midi_bytes_v1';
const _maxCachedFiles = 60;

/// Returns the MIDI file for [url], from the on-device cache when present so a
/// gig with no (or bad) venue Wi-Fi still opens the launchpad. A file behind a
/// URL never changes (a re-import gets a new URL), so a hit is always valid.
Future<Uint8List> cachedMidiBytes(
  String url,
  Future<Uint8List> Function(String url) fetch, {
  Future<Box<dynamic>> Function()? openBox,
}) async {
  Box<dynamic>? box;
  try {
    box = await (openBox ?? () => Hive.openBox<dynamic>(midiBytesBoxName))();
    final hit = box.get(url);
    if (hit is Uint8List && hit.isNotEmpty) return hit;
  } on Object catch (error) {
    // Cache unavailable (Hive not initialised): fall back to the network.
    debugPrint('[MidiCache] unavailable: $error');
  }
  final bytes = await fetch(url);
  try {
    if (box != null && bytes.isNotEmpty) {
      await box.put(url, bytes);
      while (box.length > _maxCachedFiles) {
        await box.deleteAt(0); // oldest first
      }
    }
  } on Object catch (error) {
    debugPrint('[MidiCache] could not store: $error');
  }
  return bytes;
}
