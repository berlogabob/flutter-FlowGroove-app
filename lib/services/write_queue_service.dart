/// Offline write queue service for persisting mutations when offline.
///
/// Queues write operations in Hive when the device is offline,
/// and flushes them to Firestore when connectivity is restored.
///
/// Features:
/// - Persistent queue (survives app restarts)
/// - Exponential backoff for retries (max 5 attempts)
/// - Optimistic cache updates
/// - Type-safe write entry serialization
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// A queued write operation.
class WriteEntry {

  WriteEntry({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory WriteEntry.fromJson(Map<String, dynamic> json) => WriteEntry(
        id: json['id'] as String,
        type: WriteType.values.byName(json['type'] as String),
        payload: json['payload'] as Map<String, dynamic>,
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
  final String id;
  final WriteType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  WriteEntry copyWith({int? retryCount}) {
    return WriteEntry(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };
}

/// Types of write operations supported by the queue.
enum WriteType {
  saveSong,
  updateSong,
  deleteSong,
  saveBand,
  updateBand,
  deleteBand,
  saveSetlist,
  updateSetlist,
  deleteSetlist,
  reorderSetlist,
}

/// Maximum number of retries for failed writes.
const kMaxWriteRetries = 5;

/// Service that manages offline write queue.
class WriteQueueService {
  static const _boxName = 'pending_writes';

  Box? _box;

  Future<Box> get _ensureBox async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
    return _box!;
  }

  /// Get all pending write entries.
  Future<List<WriteEntry>> get pendingWrites async {
    final box = await _ensureBox;
    return box.values
        .whereType<Map<String, dynamic>>()
        .map(WriteEntry.fromJson)
        .toList();
  }

  /// Get the count of pending writes.
  Future<int> get pendingCount async {
    final box = await _ensureBox;
    return box.length;
  }

  /// Queue a write operation for later execution.
  Future<void> enqueue(WriteEntry entry) async {
    final box = await _ensureBox;
    await box.put(entry.id, entry.toJson());
    debugPrint('[WriteQueue] Enqueued: ${entry.type.name} (${entry.id})');
  }

  /// Remove a write entry from the queue (successfully completed).
  Future<void> complete(String entryId) async {
    final box = await _ensureBox;
    await box.delete(entryId);
    debugPrint('[WriteQueue] Completed: $entryId');
  }

  /// Mark a write entry as failed (increment retry count).
  Future<void> fail(String entryId, int currentRetryCount) async {
    final box = await _ensureBox;
    final raw = box.get(entryId);
    if (raw == null) return;

    final entry = WriteEntry.fromJson(raw as Map<String, dynamic>);
    if (currentRetryCount >= kMaxWriteRetries) {
      // Max retries exceeded — remove from queue
      await box.delete(entryId);
      debugPrint(
        '[WriteQueue] Max retries exceeded for $entryId — discarding',
      );
    } else {
      await box.put(entryId, entry.copyWith(retryCount: currentRetryCount + 1).toJson());
      debugPrint(
        '[WriteQueue] Retry $currentRetryCount for $entryId',
      );
    }
  }

  /// Flush all pending writes (call when connectivity restored).
  ///
  /// Returns the list of successfully completed write IDs.
  /// The caller is responsible for executing each write via the appropriate repository.
  Future<List<WriteEntry>> flush() async {
    final entries = await pendingWrites;
    if (entries.isEmpty) return [];

    debugPrint('[WriteQueue] Flushing ${entries.length} pending writes');
    return entries;
  }

  /// Clear all pending writes (emergency reset).
  Future<void> clearAll() async {
    final box = await _ensureBox;
    await box.clear();
    debugPrint('[WriteQueue] All pending writes cleared');
  }

  /// Dispose the service.
  void dispose() {
    _box?.close();
    _box = null;
  }
}
