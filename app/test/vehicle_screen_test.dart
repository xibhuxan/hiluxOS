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

VehicleSnapshot _snapshot({bool ignition = true, bool alarmArmed = false, String? moving = 'down'}) => VehicleSnapshot(
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
      windows: [
        VehicleWindowInfo(id: 1, label: 'Conductor', position: 0),
        VehicleWindowInfo(id: 2, label: 'Pasajero', position: 0.5, moving: moving),
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
    // NOTE: no pumpAndSettle — window 2 of the snapshot is `moving: 'down'`,
    // so its interpolation Ticker runs forever (by design). Bounded pumps.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Control'), findsOneWidget);
    expect(find.text('Luces'), findsOneWidget);
    expect(find.text('Intermitentes'), findsOneWidget);
    expect(find.text('Cierre y alarma'), findsOneWidget);
    expect(find.text('Ventanillas'), findsOneWidget);
    expect(find.text('Puertas'), findsOneWidget);
    expect(find.text('Motor encendido'), findsOneWidget);

    container.dispose();
  });

  testWidgets('Dashboard mode shows gauges, metrics and tell-tales', (tester) async {
    bigViewport(tester);
    final container = containerWith(VehicleState(snapshot: _snapshot()));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 400));

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
    await tester.pump(const Duration(milliseconds: 400));

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

    // Stop the moving window (a final poll with moving == null parks its
    // interpolation Ticker) so the post-dispose pump doesn't rebuild it
    // against the disposed container.
    (container.read(vehicleProvider.notifier) as _FakeVehicleNotifier)
        .setState(VehicleState(snapshot: _snapshot(moving: null)));
    await tester.pump(const Duration(milliseconds: 400));

    container.dispose();
    // Bounded pump to flush the dashboard tell-tale timers left over from the
    // Dashboard visit (they blink forever; never pumpAndSettle).
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('moving window interpolates its bar live between polls', (tester) async {
    bigViewport(tester);
    // Window 2 starts at 0.5 moving down (full travel = 2 s, 0.5/s).
    final container = containerWith(VehicleState(snapshot: _snapshot()));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    double barWidth() => tester
        .widget<FractionallySizedBox>(find.byKey(const Key('window-bar-2')))
        .widthFactor!;
    // 400 ms have already ticked: 0.5 + 0.4s * 0.5/s = 0.7.
    expect(barWidth(), moreOrLessEquals(0.7, epsilon: 0.02));

    // After 1 s more of fake time the bar must have advanced another ~0.5
    // towards fully open (no poll happened — the movement is the local
    // interpolation, clamped at 1.0).
    await tester.pump(const Duration(seconds: 1));
    expect(barWidth(), 1.0);

    container.dispose();
  });

  testWidgets('turn signal buttons send one key at a time', (tester) async {
    bigViewport(tester);
    final fake = _FakeVehicleNotifier()..setState(VehicleState(snapshot: _snapshot()));
    final container = ProviderContainer(overrides: [vehicleProvider.overrideWith((ref) => fake)]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: VehicleScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // Fakes can't hit the network; assert the UI exposes the three one-shot
    // buttons (the API mapping is covered by vehicle_provider_test).
    expect(find.text('Izq.'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Dcha.'), findsOneWidget);

    container.dispose();
  });
}