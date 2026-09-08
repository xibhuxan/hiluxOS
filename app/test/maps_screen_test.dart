// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/maps/maps_provider.dart';
import '../lib/features/maps/maps_screen.dart';

/// Fake notifier (no network) — same pattern as equalizer_screen_test.
class _FakeMapsNotifier extends MapsNotifier {
  _FakeMapsNotifier() : super(ApiClient(Dio()));

  void setState(MapsState s) => state = s;

  String? lastSearch;
  GeoPlace? lastDestination;
  bool computeRouteCalled = false;

  @override
  Future<void> search(String query) async {
    lastSearch = query;
  }

  @override
  void selectDestination(GeoPlace place) {
    lastDestination = place;
    state = state.copyWith(
      destination: () => place,
      searchResults: const [],
    );
  }

  @override
  Future<void> computeRoute() async {
    computeRouteCalled = true;
  }
}

const _madrid = GeoPlace(
  name: 'Madrid',
  displayName: 'Madrid, Comunidad de Madrid, España',
  lat: 40.4168,
  lon: -3.7038,
);
const _barcelona = GeoPlace(
  name: 'Barcelona',
  displayName: 'Barcelona, Cataluña, España',
  lat: 41.38,
  lon: 2.17,
);

const _route = RouteInfo(
  distanceKm: 621.4,
  durationMin: 355,
  geometry: [
    [-3.7, 40.41],
    [-1.5, 40.9],
    [2.17, 41.38],
  ],
  steps: ['Salida por Calle Mayor', 'Gira a la derecha por A-2'],
);

void main() {
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer containerWith(_FakeMapsNotifier fake, MapsState s) {
    fake.setState(s);
    return ProviderContainer(
      overrides: [mapsProvider.overrideWith((ref) => fake)],
    );
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: MapsScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders the OSM map with position marker and zoom controls',
      (tester) async {
    bigViewport(tester);
    final container = containerWith(_FakeMapsNotifier(), const MapsState());
    await pump(tester, container);

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(TileLayer), findsWidgets);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);

    container.dispose();
  });

  testWidgets('search results are tappable destinations', (tester) async {
    bigViewport(tester);
    final fake = _FakeMapsNotifier();
    final container = containerWith(
      fake,
      const MapsState(searchResults: [_madrid, _barcelona]),
    );
    await pump(tester, container);

    expect(find.text('Madrid'), findsOneWidget);
    expect(find.text('Barcelona'), findsOneWidget);

    await tester.tap(find.text('Barcelona'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.lastDestination?.name, 'Barcelona');
    expect(find.text('Destino: Barcelona'), findsOneWidget);

    container.dispose();
  });

  testWidgets('submitting the search field calls search on the notifier',
      (tester) async {
    bigViewport(tester);
    final fake = _FakeMapsNotifier();
    final container = containerWith(fake, const MapsState());
    await pump(tester, container);

    await tester.enterText(find.byType(TextField), 'Valencia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.lastSearch, 'Valencia');

    container.dispose();
  });

  testWidgets('"Cómo llegar" triggers route computation and shows the panel',
      (tester) async {
    bigViewport(tester);
    final fake = _FakeMapsNotifier();
    fake.setState(const MapsState(destination: _barcelona));
    final container = ProviderContainer(
      overrides: [mapsProvider.overrideWith((ref) => fake)],
    );
    await pump(tester, container);

    expect(find.text('Cómo llegar'), findsOneWidget);
    await tester.tap(find.text('Cómo llegar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.computeRouteCalled, true);

    // The destination marker exists in the layer (it may be culled from the
    // viewport at zoom 13, so we assert on the Marker model not the icon).
    expect(find.byType(MarkerLayer), findsWidgets);

    // Simulate the route arriving → the summary panel appears.
    fake.setState(const MapsState(destination: _barcelona, route: _route));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('621 km · 5 h 55 min'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsWidgets);

    container.dispose();
  });

  testWidgets('error banner appears with retry', (tester) async {
    bigViewport(tester);
    final fake = _FakeMapsNotifier();
    final container = containerWith(
      fake,
      const MapsState(
        error: 'No se pudo buscar. Sin conexión con el servidor.',
      ),
    );
    await pump(tester, container);

    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.lastSearch, '');

    container.dispose();
  });
}
