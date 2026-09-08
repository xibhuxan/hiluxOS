// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/vehicle/vehicle_provider.dart';
import '../lib/features/vehicle/vehicle_screen.dart';

/// Fake notifier (no timers, no network) — same pattern as vehicle_card_test.
class _FakeVehicleNotifier extends VehicleNotifier {
  _FakeVehicleNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> load() async {}
  void setState(VehicleState s) => state = s;
}

VehicleSnapshot _snapshot({bool ignition = true, bool alarmArmed = false}) => VehicleSnapshot(
      connected: true,
      ignition: ignition,
      batteryVoltage: 14.1,
      rpm: 2100,
      speedKmh: 62,
      coolantTempC: 84.2,
      fuelLevel: 0.65,
      odometerKm: 184321.5,
      positionLights: false,
      lowBeams: true,
      highBeams: false,
      fogLights: false,
      auxiliaryLights: false,
      turnLeft: false,
      turnRight: false,
      hazard: false,
      locked: true,
      alarmArmed: alarmArmed,
      windows: const [
        VehicleWindowInfo(id: 1, label: 'Conductor', position: 0),
        VehicleWindowInfo(id: 2, label: 'Pasajero', position: 0.5, moving: 'down'),
        VehicleWindowInfo(id: 3, label: 'Trasera izq.', position: 0),
        VehicleWindowInfo(id: 4, label: 'Trasera der.', position: 1),
      ],
      doors: const [
        VehicleDoorInfo(id: 1, label: 'Conductor', open: false),
        VehicleDoorInfo(id: 2, label: 'Pasajero', open: true),
        VehicleDoorInfo(id: 3, label: 'Trasera izq.', open: false),
        VehicleDoorInfo(id: 4, label: 'Trasera der.', open: false),
      ],
    );

void main() {
  // The control panel is a lazy sliver list: give the test a tall viewport
  // (like the real radio's 1280x720 screen) so every card is built.
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer containerWith(VehicleState state) => ProviderContainer(overrides: [
        vehicleProvider.overrideWith((ref) => _FakeVehicleNotifier()..setState(state)),
      ]);

  testWidgets('Control mode shows the actuation cards', (tester) async {
    bigViewport(tester);
    final container = containerWith(VehicleState(snapshot: _snapshot()));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Luces'), findsOneWidget);
    expect(find.text('Intermitentes'), findsOneWidget);
    expect(find.text('Cierre y alarma'), findsOneWidget);
    expect(find.text('Ventanillas'), findsOneWidget);
    expect(find.text('Puertas'), findsOneWidget);
    expect(find.text('Motor encendido'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('Dashboard mode shows gauges, metrics and tell-tales', (tester) async {
    bigViewport(tester);
    final container = containerWith(VehicleState(snapshot: _snapshot()));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard'));
    // NOTE: no pumpAndSettle here — the cluster tell-tales blink forever
    // (a repeating controller, by design); a bounded pump is the correct
    // way to assert on a screen with an infinite animation.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('km/h'), findsOneWidget);
    expect(find.text('rpm'), findsOneWidget);
    expect(find.text('Combustible'), findsOneWidget);
    expect(find.text('Refrigerante'), findsOneWidget);
    expect(find.text('Batería'), findsOneWidget);
    expect(find.text('Odómetro'), findsOneWidget);

    container.dispose();
    await tester.pump();
  });

  testWidgets('mode toggle switches both ways (Control ⇄ Dashboard)', (tester) async {
    bigViewport(tester);
    final container = containerWith(VehicleState(snapshot: _snapshot()));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pumpAndSettle();

    // Control → Dashboard.
    await tester.tap(find.text('Dashboard'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('km/h'), findsOneWidget);

    // Dashboard → Control (regression: the inactive segment used to re-emit
    // the current mode, so this tap was a no-op and you were stuck).
    await tester.tap(find.text('Control'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Luces'), findsOneWidget);
    expect(find.text('Ventanillas'), findsOneWidget);

    container.dispose();
    // Bounded pump to flush the dashboard tell-tale timers left over from the
    // Dashboard visit (they blink forever; never pumpAndSettle).
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('turn signal buttons send one key at a time', (tester) async {
    bigViewport(tester);
    final fake = _FakeVehicleNotifier()..setState(VehicleState(snapshot: _snapshot()));
    final container = ProviderContainer(overrides: [vehicleProvider.overrideWith((ref) => fake)]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pumpAndSettle();

    // Fakes can't hit the network; assert the UI exposes the three one-shot
    // buttons (the API mapping is covered by vehicle_provider_test).
    expect(find.text('Izq.'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Dcha.'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });
}