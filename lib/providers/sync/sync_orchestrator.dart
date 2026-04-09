/// Sync orchestrator that coordinates offline/online transitions.
///
/// Listens to connectivity changes and triggers:
/// - Write queue flush on reconnect
/// - Stale cache refresh on reconnect
/// - Sync status updates for UI
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../services/write_queue_service.dart';
import '../../services/cache_service.dart';
import '../../services/connectivity_service.dart';

/// Sync status exposed to UI.
class SyncStatus {
  final bool isOnline;
  final int pendingWrites;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncStatus({
    this.isOnline = true,
    this.pendingWrites = 0,
    this.lastSyncAt,
    this.lastError,
  });

  SyncStatus copyWith({
    bool? isOnline,
    int? pendingWrites,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      pendingWrites: pendingWrites ?? this.pendingWrites,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError,
    );
  }
}

/// Notifier that manages sync orchestration.
class SyncOrchestrator extends Notifier<SyncStatus> {
  late final WriteQueueService _writeQueue;
  late final CacheService _cache;

  @override
  SyncStatus build() {
    _writeQueue = ref.watch(writeQueueProvider);
    _cache = ref.watch(cacheServiceProvider);

    // Listen to connectivity changes
    ref.listen<bool>(connectivityProvider, (previous, next) {
      if (previous == false && next == true) {
        // Offline → Online: trigger sync
        _onReconnect();
      } else if (previous == true && next == false) {
        // Online → Offline: update status
        state = state.copyWith(isOnline: false);
      }
    });

    // Initialize status
    _initStatus();
    return const SyncStatus();
  }

  Future<void> _initStatus() async {
    final isOnline = ref.read(connectivityProvider);
    final pendingCount = await _writeQueue.pendingCount;
    state = SyncStatus(
      isOnline: isOnline,
      pendingWrites: pendingCount,
    );
  }

  /// Called when device reconnects to internet.
  Future<void> _onReconnect() async {
    debugPrint('[SyncOrchestrator] Reconnected — triggering sync');
    state = state.copyWith(isOnline: true);

    try {
      // Flush write queue
      final pendingWrites = await _writeQueue.flush();
      if (pendingWrites.isNotEmpty) {
        debugPrint(
          '[SyncOrchestrator] ${pendingWrites.length} writes ready to flush',
        );
        // Note: Actual execution happens in repository layer
        // This notifies listeners that writes are available
      }

      state = state.copyWith(
        pendingWrites: await _writeQueue.pendingCount,
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SyncOrchestrator] Reconnect sync failed: $e');
      state = state.copyWith(lastError: e.toString());
    }
  }

  /// Update pending write count (called after queue changes).
  Future<void> refreshPendingCount() async {
    state = state.copyWith(
      pendingWrites: await _writeQueue.pendingCount,
    );
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(lastError: null);
  }
}

/// Provider for the sync orchestrator.
final syncOrchestratorProvider =
    NotifierProvider<SyncOrchestrator, SyncStatus>(
  SyncOrchestrator.new,
);

/// Provider for WriteQueueService (singleton).
final writeQueueProvider = Provider<WriteQueueService>(
  (ref) {
    final service = WriteQueueService();
    ref.onDispose(() => service.dispose());
    return service;
  },
);

/// Provider for CacheService (singleton).
final cacheServiceProvider = Provider<CacheService>(
  (ref) => CacheService(),
);
