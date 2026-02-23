import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ConnectivityService monitors network connectivity status.
///
/// Provides real-time updates on whether the device is online or offline.
class ConnectivityService extends Notifier<bool> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  bool build() {
    _initConnectivity();
    return true; // Assume online initially
  }

  /// Initializes connectivity monitoring.
  Future<void> _initConnectivity() async {
    // Get initial connectivity status
    final result = await _connectivity.checkConnectivity();
    state = _isConnected(result);

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      state = _isConnected(results);
    });
  }

  /// Determines if the device is connected based on connectivity results.
  bool _isConnected(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Returns true if the device is currently online.
  bool get isOnline => state;

  /// Returns true if the device is currently offline.
  bool get isOffline => !state;

  void dispose() {
    _subscription?.cancel();
  }
}

/// Provider for connectivity status.
///
/// Usage:
/// ```dart
/// final isOnline = ref.watch(connectivityProvider);
/// ```
final connectivityProvider = NotifierProvider<ConnectivityService, bool>(() {
  return ConnectivityService();
});

/// Provider that returns true when device is offline.
final offlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider) == false;
});
