import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Injectable connectivity client boundary for production and tests.
abstract class ConnectivityClient {
  Future<List<ConnectivityResult>> checkConnectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

/// Production implementation backed by `connectivity_plus`.
class ConnectivityPlusClient implements ConnectivityClient {
  ConnectivityPlusClient({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    return _connectivity.checkConnectivity();
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }
}

/// Provider for the production connectivity client.
final connectivityClientProvider = Provider<ConnectivityClient>((ref) {
  return ConnectivityPlusClient();
});

/// Verifies real reachability with an actual HTTP request.
///
/// `connectivity_plus` on web is just `navigator.onLine`, which browsers
/// (Brave/VPNs/virtual adapters) misreport as offline while the network works.
/// "Offline" is only trusted after this probe also fails.
final reachabilityProbeProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://app.flowgroove.app/version.json'
              '?ts=${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  };
});

/// ConnectivityService monitors network connectivity status.
///
/// Provides real-time updates on whether the device is online or offline.
///
/// IMPORTANT: This service properly disposes of stream subscriptions
/// when the provider is disposed to prevent memory leaks.
class ConnectivityService extends Notifier<bool> {
  // ignore: cancel_subscriptions
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineRecheckTimer;
  bool _isDisposed = false;

  @override
  bool build() {
    _disposeSubscription();
    _isDisposed = false;
    ref.onDispose(_disposeSubscription);

    final client = ref.read(connectivityClientProvider);
    unawaited(_initConnectivity(client));
    return true; // Assume online initially
  }

  /// Initializes connectivity monitoring.
  Future<void> _initConnectivity(ConnectivityClient client) async {
    try {
      final result = await client.checkConnectivity();
      await _applyResults(result);
    } catch (e) {
      debugPrint('ConnectivityService initial check failed: $e');
    }

    if (_isDisposed) {
      return;
    }

    try {
      _subscription = client.onConnectivityChanged.listen(
        (results) {
          unawaited(_applyResults(results));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('ConnectivityService stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('ConnectivityService stream setup failed: $e');
    }
  }

  /// Applies a connectivity reading; "offline" is verified with a real
  /// request first, since navigator.onLine lies on web.
  Future<void> _applyResults(List<ConnectivityResult> results) async {
    if (_isDisposed) return;
    if (_isConnected(results)) {
      _stopOfflineRecheck();
      state = true;
      return;
    }
    await _verifyOffline();
  }

  Future<void> _verifyOffline() async {
    final probe = ref.read(reachabilityProbeProvider);
    final reachable = await probe();
    if (_isDisposed) return;
    if (reachable) {
      _stopOfflineRecheck();
      state = true;
    } else {
      state = false;
      _startOfflineRecheck();
    }
  }

  // ponytail: 30s polling only while offline; event-driven when online
  void _startOfflineRecheck() {
    _offlineRecheckTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_verifyOffline()),
    );
  }

  void _stopOfflineRecheck() {
    _offlineRecheckTimer?.cancel();
    _offlineRecheckTimer = null;
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

  void _disposeSubscription() {
    _isDisposed = true;
    _stopOfflineRecheck();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
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
  return !ref.watch(connectivityProvider);
});
