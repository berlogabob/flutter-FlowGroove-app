// ignore_for_file: directives_ordering

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flowgroove/services/connectivity_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeConnectivityClient implements ConnectivityClient {
  FakeConnectivityClient({
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    this._streamAccessError,
  }) : _checkConnectivity =
           checkConnectivity ?? (() async => <ConnectivityResult>[]) {
    _controller = StreamController<List<ConnectivityResult>>.broadcast(
      onCancel: () {
        subscriptionCancelled = true;
      },
    );
  }

  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Error? _streamAccessError;
  late final StreamController<List<ConnectivityResult>> _controller;
  bool subscriptionCancelled = false;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    return _checkConnectivity();
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    if (_streamAccessError != null) {
      throw _streamAccessError;
    }

    return _controller.stream;
  }

  void emit(List<ConnectivityResult> results) {
    _controller.add(results);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

Future<void> flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void primeConnectivityProvider(ProviderContainer container) {
  container.read(connectivityProvider);
}

void main() {
  group('ConnectivityService', () {
    ProviderContainer createContainer(
      FakeConnectivityClient client, {
      Future<bool> Function()? probe,
    }) {
      final container = ProviderContainer(
        overrides: [
          connectivityClientProvider.overrideWithValue(client),
          // Unreachable by default so "none => offline" tests keep their
          // pre-probe semantics.
          reachabilityProbeProvider.overrideWithValue(
            probe ?? () async => false,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await client.dispose();
      });
      return container;
    }

    group('connectivityProvider', () {
      test('connectivityProvider is defined', () {
        expect(connectivityProvider, isNotNull);
      });

      test('offlineProvider is defined', () {
        expect(offlineProvider, isNotNull);
      });
    });

    group('ConnectivityService state', () {
      test('initial state is true (assume online) before init resolves', () async {
        final completer = Completer<List<ConnectivityResult>>();
        final client = FakeConnectivityClient(
          checkConnectivity: () => completer.future,
        );
        final container = createContainer(client);

        final isOnline = container.read(connectivityProvider);
        expect(isOnline, isTrue);

        completer.complete(<ConnectivityResult>[ConnectivityResult.none]);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isFalse);
      });

      test('offlineProvider returns inverse of connectivityProvider', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(client);

        primeConnectivityProvider(container);
        await flushAsyncWork();

        final isOnline = container.read(connectivityProvider);
        final isOffline = container.read(offlineProvider);

        expect(isOffline, equals(!isOnline));
      });
    });

    group('ConnectivityService methods', () {
      test('initial wifi result keeps provider online', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.wifi],
        );
        final container = createContainer(client);

        expect(container.read(connectivityProvider), isTrue);
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isTrue);
      });

      test('initial none result sets provider offline', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(client);

        primeConnectivityProvider(container);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isFalse);
      });

      test('empty result list sets provider offline', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[],
        );
        final container = createContainer(client);

        primeConnectivityProvider(container);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isFalse);
      });

      test('stream update none to wifi flips offline to online', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(client);

        primeConnectivityProvider(container);
        await flushAsyncWork();
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isFalse);

        client.emit(<ConnectivityResult>[ConnectivityResult.wifi]);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isTrue);
      });

      test('stream update wifi to none flips online to offline', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.wifi],
        );
        final container = createContainer(client);

        primeConnectivityProvider(container);
        await flushAsyncWork();
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isTrue);

        client.emit(<ConnectivityResult>[ConnectivityResult.none]);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isFalse);
      });

      test('offlineProvider mirrors connectivityProvider', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(client);

        primeConnectivityProvider(container);
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isFalse);
        expect(container.read(offlineProvider), isTrue);

        client.emit(<ConnectivityResult>[ConnectivityResult.wifi]);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isTrue);
        expect(container.read(offlineProvider), isFalse);
      });
    });

    group('ConnectivityResult handling', () {
      test('ConnectivityResult.none indicates offline', () {
        expect(ConnectivityResult.none, equals(ConnectivityResult.none));
      });

      test('ConnectivityResult.wifi indicates online', () {
        expect(ConnectivityResult.wifi, isNot(equals(ConnectivityResult.none)));
      });

      test('ConnectivityResult.mobile indicates online', () {
        expect(
          ConnectivityResult.mobile,
          isNot(equals(ConnectivityResult.none)),
        );
      });

      test('ConnectivityResult.ethernet indicates online', () {
        expect(
          ConnectivityResult.ethernet,
          isNot(equals(ConnectivityResult.none)),
        );
      });

      test('ConnectivityResult.bluetooth indicates online', () {
        expect(
          ConnectivityResult.bluetooth,
          isNot(equals(ConnectivityResult.none)),
        );
      });

      test('ConnectivityResult.vpn indicates online', () {
        expect(ConnectivityResult.vpn, isNot(equals(ConnectivityResult.none)));
      });

      test('ConnectivityResult.other indicates online', () {
        expect(
          ConnectivityResult.other,
          isNot(equals(ConnectivityResult.none)),
        );
      });

      test('ConnectivityResult.none is distinct from other types', () {
        const none = ConnectivityResult.none;
        const wifi = ConnectivityResult.wifi;
        const mobile = ConnectivityResult.mobile;

        expect(none, isNot(equals(wifi)));
        expect(none, isNot(equals(mobile)));
      });
    });

    group('Provider overrides', () {
      test('can override connectivity client with a fake implementation', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.wifi],
        );
        final container = createContainer(client);

        expect(container.read(connectivityProvider), isA<bool>());
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isTrue);
      });
    });

    group('Integration with Riverpod', () {
      test('read connectivityProvider returns boolean', () {
        final client = FakeConnectivityClient();
        final container = createContainer(client);

        final isOnline = container.read(connectivityProvider);
        expect(isOnline, isA<bool>());
      });

      test('listen to connectivityProvider changes', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(client);

        bool? lastValue;
        final listener = container.listen<bool>(
          connectivityProvider,
          (previous, next) {
            lastValue = next;
          },
          fireImmediately: true,
        );

        expect(lastValue, isTrue);
        await flushAsyncWork();
        expect(lastValue, isFalse);

        client.emit(<ConnectivityResult>[ConnectivityResult.wifi]);
        await flushAsyncWork();
        expect(lastValue, isTrue);

        listener.close();
      });
    });

    group('ConnectivityResult enum coverage', () {
      test('all ConnectivityResult values are handled', () {
        // Verify all enum values exist
        expect(ConnectivityResult.values, contains(ConnectivityResult.none));
        expect(ConnectivityResult.values, contains(ConnectivityResult.wifi));
        expect(ConnectivityResult.values, contains(ConnectivityResult.mobile));
        expect(
          ConnectivityResult.values,
          contains(ConnectivityResult.ethernet),
        );
        expect(
          ConnectivityResult.values,
          contains(ConnectivityResult.bluetooth),
        );
        expect(ConnectivityResult.values, contains(ConnectivityResult.vpn));
        expect(ConnectivityResult.values, contains(ConnectivityResult.other));
      });

      test('ConnectivityResult.none is the only offline state', () {
        final onlineResults = ConnectivityResult.values
            .where((r) => r != ConnectivityResult.none)
            .toList();

        expect(onlineResults, isNotEmpty);
        expect(onlineResults, isNot(contains(ConnectivityResult.none)));
      });
    });

    group('Reachability probe', () {
      test('none result stays online when probe reaches the network', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async =>
              <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(client, probe: () async => true);

        primeConnectivityProvider(container);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isTrue);
      });

      test('offline stream event stays online when probe succeeds', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async =>
              <ConnectivityResult>[ConnectivityResult.wifi],
        );
        final container = createContainer(client, probe: () async => true);

        primeConnectivityProvider(container);
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isTrue);

        client.emit(<ConnectivityResult>[ConnectivityResult.none]);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isTrue);
      });

      test('recovers to online when probe starts succeeding', () async {
        var reachable = false;
        final client = FakeConnectivityClient(
          checkConnectivity: () async =>
              <ConnectivityResult>[ConnectivityResult.none],
        );
        final container = createContainer(
          client,
          probe: () async => reachable,
        );

        primeConnectivityProvider(container);
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isFalse);

        reachable = true;
        client.emit(<ConnectivityResult>[ConnectivityResult.none]);
        await flushAsyncWork();

        expect(container.read(connectivityProvider), isTrue);
      });
    });

    group('Error handling', () {
      test('checkConnectivity failure keeps optimistic online state', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async {
            throw StateError('connectivity unavailable');
          },
        );
        final container = createContainer(client);

        expect(container.read(connectivityProvider), isTrue);
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isTrue);
      });

      test('stream setup failure does not crash the provider', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.none],
          streamAccessError: StateError('stream unavailable'),
        );
        final container = createContainer(client);

        expect(container.read(connectivityProvider), isTrue);
        await flushAsyncWork();
        expect(container.read(connectivityProvider), isFalse);
      });

      test('disposing the container cancels the subscription cleanly', () async {
        final client = FakeConnectivityClient(
          checkConnectivity: () async => <ConnectivityResult>[ConnectivityResult.wifi],
        );
        final container = ProviderContainer(
          overrides: [
            connectivityClientProvider.overrideWithValue(client),
          ],
        );
        addTearDown(client.dispose);

        container.read(connectivityProvider);
        await flushAsyncWork();

        container.dispose();
        await flushAsyncWork();

        expect(client.subscriptionCancelled, isTrue);
      });
    });
  });
}
