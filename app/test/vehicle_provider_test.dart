// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/vehicle/vehicle_provider.dart';

/// A Dio adapter that returns a canned JSON payload for every request and
/// records the calls (same pattern as media_provider_test.dart).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);
  final Object? Function(RequestOptions) _handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelToken,
  ) async {
    requests.add(options);
    final body = _handler(options);
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody(
      Stream.value(Uint8List.fromList(bytes)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _api(Object? Function(RequestOptions) handler) {
  final dio = Dio()..httpClientAdapter = _FakeAdapter(handler);
  return ApiClient(dio);
}

const snapshotJson = {
  'connected': true,
  'ignition': true,
  'batteryVoltage': 14.1,
  'engine': {
    'rpm': 2100,
    'speedKmh': 62,
    'coolantTempC': 84.2,
    'fuelLevel': 0.65,
    'odometerKm': 184321.5,
  },
  'lights': {'position': false, 'low': true, 'high': false, 'fog': false, 'auxiliary': false},
  'turnSignals': {'left': false, 'right': false, 'hazard': true},
  'centralLock': {'locked': true},
  'windows': [
    {'id': 1, 'label': 'Conductor', 'position': 0.0, 'moving': null},
    {'id': 2, 'label': 'Pasajero', 'position': 0.5, 'moving': 'down'},
    {'id': 3, 'label': 'Trasera izq.', 'position': 0.0, 'moving': null},
    {'id': 4, 'label': 'Trasera der.', 'position': 1.0, 'moving': null},
  ],
  'doors': [
    {'id': 1, 'label': 'Conductor', 'open': false},
    {'id': 2, 'label': 'Pasajero', 'open': false},
    {'id': 3, 'label': 'Trasera izq.', 'open': false},
    {'id': 4, 'label': 'Trasera der.', 'open': false},
  ],
};

void main() {
  group('VehicleSnapshot.fromJson', () {
    test('parses the full backend snapshot', () {
      final s = VehicleSnapshot.fromJson(Map<String, dynamic>.from(snapshotJson));
      expect(s.connected, isTrue);
      expect(s.speedKmh, 62);
      expect(s.rpm, 2100);
      expect(s.coolantTempC, 84.2);
      expect(s.fuelLevel, 0.65);
      expect(s.batteryVoltage, 14.1);
      expect(s.lowBeams, isTrue);
      expect(s.hazard, isTrue);
      expect(s.locked, isTrue);
      expect(s.windows.length, 4);
      expect(s.windowsClosed, 2); // ids 1 and 3 (position <= 0.01)
      expect(s.doors.length, 4);
      expect(s.doorsClosed, 4);
      expect(s.turnRight, isFalse); // full model now carries per-signal state
    });

    test('degrades gracefully on a disconnected snapshot', () {
      const empty = {
        'connected': false,
        'ignition': false,
        'batteryVoltage': null,
        'engine': {
          'rpm': null,
          'speedKmh': null,
          'coolantTempC': null,
          'fuelLevel': null,
          'odometerKm': null,
        },
        'lights': {'position': false, 'low': false, 'high': false, 'fog': false, 'auxiliary': false},
        'turnSignals': {'left': false, 'right': false, 'hazard': false},
        'centralLock': {'locked': false},
        'alarm': {'armed': false},
        'windows': <dynamic>[],
        'doors': <dynamic>[],
      };
      final s = VehicleSnapshot.fromJson(Map<String, dynamic>.from(empty));
      expect(s.connected, isFalse);
      expect(s.speedKmh, isNull);
      expect(s.windows, isEmpty);
      expect(s.doorsClosed, 0);
    });
  });

  group('VehicleNotifier', () {
    // Dio's request pipeline spans several event-loop turns; give the
    // constructor's initial load() real time to finish (plain test(), not
    // testWidgets, so real async is fine).
    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

    test('load() populates the snapshot from GET /vehicle', () async {
      final api = _api((options) => snapshotJson);
      final notifier = VehicleNotifier(api);
      await settle();
      expect(notifier.state.snapshot, isNotNull);
      expect(notifier.state.snapshot!.connected, isTrue);
      expect(notifier.state.error, isNull);
      notifier.dispose();
    });

    test('setLock() PUTs /vehicle/lock and applies the returned snapshot', () async {
      final requests = <RequestOptions>[];
      final api = _api((options) {
        requests.add(options);
        return snapshotJson;
      });
      final notifier = VehicleNotifier(api);
      await settle();
      await notifier.setLock(true);
      expect(requests.any((r) => r.path == '/vehicle/lock'), isTrue);
      notifier.dispose();
    });

    test('setIgnition() PUTs /vehicle/ignition', () async {
      final requests = <RequestOptions>[];
      final api = _api((options) {
        requests.add(options);
        return snapshotJson;
      });
      final notifier = VehicleNotifier(api);
      await settle();
      await notifier.setIgnition(false);
      expect(requests.any((r) => r.path == '/vehicle/ignition'), isTrue);
      notifier.dispose();
    });

    test('setDoor() PUTs /vehicle/doors/:id', () async {
      final requests = <RequestOptions>[];
      final api = _api((options) {
        requests.add(options);
        return snapshotJson;
      });
      final notifier = VehicleNotifier(api);
      await settle();
      await notifier.setDoor(2, true);
      expect(requests.any((r) => r.path == '/vehicle/doors/2'), isTrue);
      notifier.dispose();
    });

    test('setAlarm() PUTs /vehicle/alarm', () async {
      final requests = <RequestOptions>[];
      final api = _api((options) {
        requests.add(options);
        return snapshotJson;
      });
      final notifier = VehicleNotifier(api);
      await settle();
      await notifier.setAlarm(true);
      expect(requests.any((r) => r.path == '/vehicle/alarm'), isTrue);
      notifier.dispose();
    });

    test('setSignals() PUTs /vehicle/signals with one key', () async {
      RequestOptions? signalsRequest;
      final api = _api((options) {
        if (options.path == '/vehicle/signals') signalsRequest = options;
        return snapshotJson;
      });
      final notifier = VehicleNotifier(api);
      await settle();
      await notifier.setSignals(left: true);
      expect(signalsRequest, isNotNull);
      expect(signalsRequest!.data, {'left': true});
      notifier.dispose();
    });

    test('load() keeps the last snapshot on a transport error', () async {
      var failing = false;
      final api = _api((options) {
        if (failing) {
          throw DioException.connectionError(requestOptions: options, reason: 'boom');
        }
        return snapshotJson;
      });
      final notifier = VehicleNotifier(api);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final before = notifier.state.snapshot;
      failing = true;
      await notifier.load();
      expect(notifier.state.snapshot, same(before));
      expect(notifier.state.error, isNotNull);
      notifier.dispose();
    });
  });
}