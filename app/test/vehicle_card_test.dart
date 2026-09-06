// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/home/widgets/vehicle_card.dart';
import '../lib/features/vehicle/vehicle_provider.dart';

/// Fake notifiers (no timers, no network) — same pattern as the other card
/// tests: extend the real notifier, hand it a throwaway ApiClient, override
/// the data-loading method, and set the state directly.
class _FakeVehicleNotifier extends VehicleNotifier {
  _FakeVehicleNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> load() async {}
  void setState(VehicleState s) => state = s;
}

VehicleSnapshot _snapshot({
  bool connected = true,
  int speedKmh = 62,
  int rpm = 2100,
  bool lowBeams = true,
  bool hazard = false,
  bool locked = true,
  int windowsClosed = 4,
  int windowsTotal = 4,
  int doorsClosed = 4,
  int doorsTotal = 4,
}) =>
    VehicleSnapshot(
      connected: connected,
      ignition: true,
      batteryVoltage: 14.1,
      rpm: rpm,
      speedKmh: speedKmh,
      coolantTempC: 84.2,
      fuelLevel: 0.65,
      odometerKm: 184321.5,
      lowBeams: lowBeams,
      hazard: hazard,
      locked: locked,
      windowsTotal: windowsTotal,
      windowsClosed: windowsClosed,
      doorsTotal: doorsTotal,
      doorsClosed: doorsClosed,
    );

void main() {
  testWidgets('connected snapshot shows live telemetry with chips', (tester) async {
    final container = ProviderContainer(overrides: [
      vehicleProvider.overrideWith((ref) => _FakeVehicleNotifier()
        ..setState(VehicleState(
            snapshot: _snapshot(
                lowBeams: true, hazard: true, locked: true, windowsClosed: 3, windowsTotal: 4)))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleCard())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Vehículo'), findsOneWidget);
    expect(find.text('62'), findsOneWidget);
    expect(find.text('2100 rpm'), findsOneWidget);
    expect(find.text('Cortas'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.text('3/4 ventanillas'), findsOneWidget);
    expect(find.text('En marcha'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('unconnected snapshot degrades to "No conectado"', (tester) async {
    final container = ProviderContainer(overrides: [
      vehicleProvider.overrideWith((ref) => _FakeVehicleNotifier()
        ..setState(VehicleState(snapshot: _snapshot(connected: false)))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleCard())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No conectado'), findsOneWidget);
    expect(find.text('Esperando a la centralita del vehículo'), findsOneWidget);
    expect(find.text('En marcha'), findsNothing);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('backend unreachable (error, no snapshot) shows the offline state', (tester) async {
    final container = ProviderContainer(overrides: [
      vehicleProvider.overrideWith(
          (ref) => _FakeVehicleNotifier()..setState(VehicleState(error: 'boom'))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleCard())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No conectado'), findsOneWidget);
    expect(find.text('Backend no disponible'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });
}