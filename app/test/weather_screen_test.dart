// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/weather/weather_provider.dart';
import '../lib/features/weather/weather_screen.dart';

/// Fake notifier (no network) — same pattern as equalizer_screen_test.
class _FakeWeatherNotifier extends WeatherNotifier {
  _FakeWeatherNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }
  bool refreshCalled = false;
  String? lastCity;
  void setState(WeatherState s) => state = s;

  @override
  Future<void> searchCity(String city) async {
    lastCity = city;
  }
}

WeatherState _loadedState() => const WeatherState(
      loading: false,
      current: CurrentWeather(
        locationName: 'Madrid, España',
        temperature: 18.5,
        apparentTemperature: 17.2,
        humidity: 55,
        weatherCode: 2,
        description: 'Parcialmente nublado',
        icon: 'cloud_queue',
        windSpeed: 12.3,
        windDirection: 230,
      ),
      hourly: [
        HourlyEntry(
            time: '2025-06-01T14:00',
            temperature: 20,
            weatherCode: 0,
            icon: 'wb_sunny',
            precipitationProbability: 0),
        HourlyEntry(
            time: '2025-06-01T15:00',
            temperature: 21,
            weatherCode: 61,
            icon: 'grain',
            precipitationProbability: 40),
      ],
      daily: [
        DailyEntry(
            date: '2025-06-01',
            weatherCode: 0,
            icon: 'wb_sunny',
            tempMax: 25,
            tempMin: 12,
            precipitationProbability: 0),
        DailyEntry(
            date: '2025-06-02',
            weatherCode: 61,
            icon: 'grain',
            tempMax: 20,
            tempMin: 10,
            precipitationProbability: 40),
      ],
    );

void main() {
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer containerWith(WeatherState s, [_FakeWeatherNotifier? fake]) {
    final f = fake ?? _FakeWeatherNotifier();
    f.setState(s);
    return ProviderContainer(overrides: [weatherProvider.overrideWith((ref) => f)]);
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: WeatherScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows loading spinner while loading', (tester) async {
    bigViewport(tester);
    final container = containerWith(const WeatherState(loading: true));
    await pump(tester, container);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    container.dispose();
  });

  testWidgets('renders current conditions, hourly and daily forecast', (tester) async {
    bigViewport(tester);
    final container = containerWith(_loadedState());
    await pump(tester, container);

    // Current conditions.
    expect(find.text('Madrid, España'), findsOneWidget);
    expect(find.text('19°'), findsOneWidget); // 18.5 rounds to 19
    expect(find.text('Parcialmente nublado'), findsOneWidget);
    expect(find.text('Sensación 17°'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(find.text('12 km/h'), findsOneWidget);
    // Detail labels.
    expect(find.text('Humedad'), findsOneWidget);
    expect(find.text('Viento'), findsOneWidget);
    expect(find.text('Dirección'), findsOneWidget);
    // Hourly section.
    expect(find.text('Próximas horas'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
    // Daily section.
    expect(find.text('Próximos días'), findsOneWidget);
    expect(find.text('Dom'), findsOneWidget); // 2025-06-01 was a Sunday
    expect(find.text('Lun'), findsOneWidget); // 2025-06-02 was a Monday

    container.dispose();
  });

  testWidgets('shows the error state with retry when loading fails', (tester) async {
    bigViewport(tester);
    final fake = _FakeWeatherNotifier();
    final container = containerWith(
      const WeatherState(loading: false, error: 'DioException: connection error'),
      fake,
    );
    await pump(tester, container);

    expect(find.text('No se pudo cargar el clima'), findsOneWidget);
    expect(find.text('Comprueba la conexión a internet'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.refreshCalled, true);

    container.dispose();
  });

  testWidgets('submitting a city search calls searchCity on the notifier',
      (tester) async {
    bigViewport(tester);
    final fake = _FakeWeatherNotifier();
    final container = containerWith(_loadedState(), fake);
    await pump(tester, container);

    await tester.enterText(find.byType(TextField), 'Barcelona');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.lastCity, 'Barcelona');

    container.dispose();
  });

  testWidgets('maps WMO icon names to Material icons', (tester) async {
    expect(weatherIcon('wb_sunny'), Icons.wb_sunny);
    expect(weatherIcon('cloud'), Icons.cloud);
    expect(weatherIcon('grain'), Icons.grain);
    expect(weatherIcon('ac_unit'), Icons.ac_unit);
    expect(weatherIcon('flash_on'), Icons.flash_on);
    expect(weatherIcon('unknown'), Icons.help_outline);
  });

  testWidgets('converts wind direction degrees to a compass label', (tester) async {
    expect(windDirectionLabel(0), 'N');
    expect(windDirectionLabel(90), 'E');
    expect(windDirectionLabel(180), 'S');
    expect(windDirectionLabel(230), 'SO');
    expect(windDirectionLabel(270), 'O');
    expect(windDirectionLabel(315), 'NO');
  });
}
