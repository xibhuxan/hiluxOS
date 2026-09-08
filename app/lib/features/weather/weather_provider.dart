import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Sentinel for `copyWith(error: ...)` — distinguishes "not passed" (keep the
/// current error) from an explicit `null` (clear it). Same pattern as radio.
const _unsetError = Object();

class CurrentWeather {
  final String locationName;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final int weatherCode;
  final String description;
  final String icon;
  final double windSpeed;
  final int windDirection;

  const CurrentWeather({
    required this.locationName,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.windDirection,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as Map<String, dynamic>;
    return CurrentWeather(
      locationName: loc['name'] as String? ?? '',
      temperature: (j['temperature'] as num).toDouble(),
      apparentTemperature: (j['apparentTemperature'] as num).toDouble(),
      humidity: (j['humidity'] as num).toInt(),
      weatherCode: (j['weatherCode'] as num).toInt(),
      description: j['description'] as String? ?? '',
      icon: j['icon'] as String? ?? 'help_outline',
      windSpeed: (j['windSpeed'] as num).toDouble(),
      windDirection: (j['windDirection'] as num).toInt(),
    );
  }
}

class HourlyEntry {
  final String time;
  final double temperature;
  final int weatherCode;
  final String icon;
  final int precipitationProbability;

  const HourlyEntry({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.icon,
    required this.precipitationProbability,
  });

  factory HourlyEntry.fromJson(Map<String, dynamic> j) => HourlyEntry(
        time: j['time'] as String? ?? '',
        temperature: (j['temperature'] as num).toDouble(),
        weatherCode: (j['weatherCode'] as num).toInt(),
        icon: j['icon'] as String? ?? 'help_outline',
        precipitationProbability: (j['precipitationProbability'] as num).toInt(),
      );

  /// "HH:mm" from the ISO local datetime returned by Open-Meteo (2025-06-01T14:00).
  String get hourLabel => time.length >= 16 ? time.substring(11, 16) : time;
}

class DailyEntry {
  final String date;
  final int weatherCode;
  final String icon;
  final double tempMax;
  final double tempMin;
  final int precipitationProbability;

  const DailyEntry({
    required this.date,
    required this.weatherCode,
    required this.icon,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationProbability,
  });

  factory DailyEntry.fromJson(Map<String, dynamic> j) => DailyEntry(
        date: j['date'] as String? ?? '',
        weatherCode: (j['weatherCode'] as num).toInt(),
        icon: j['icon'] as String? ?? 'help_outline',
        tempMax: (j['tempMax'] as num).toDouble(),
        tempMin: (j['tempMin'] as num).toDouble(),
        precipitationProbability: (j['precipitationProbability'] as num).toInt(),
      );
}

/// Immutable snapshot of the weather feature.
class WeatherState {
  final CurrentWeather? current;
  final List<HourlyEntry> hourly;
  final List<DailyEntry> daily;
  final bool loading;
  final String? error;

  const WeatherState({
    this.current,
    this.hourly = const [],
    this.daily = const [],
    this.loading = false,
    this.error,
  });

  WeatherState copyWith({
    CurrentWeather? Function()? current,
    List<HourlyEntry>? hourly,
    List<DailyEntry>? daily,
    bool? loading,
    Object? error = _unsetError,
  }) =>
      WeatherState(
        current: current != null ? current() : this.current,
        hourly: hourly ?? this.hourly,
        daily: daily ?? this.daily,
        loading: loading ?? this.loading,
        error: error == _unsetError ? this.error : error as String?,
      );
}

class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier(this._api) : super(const WeatherState()) {
    refresh();
  }
  final ApiClient _api;

  /// Load current conditions + forecast for the default (or saved) location.
  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final curRes = await _api.get('/weather');
      final fcRes = await _api.get('/weather/forecast');
      final current =
          CurrentWeather.fromJson(curRes.data as Map<String, dynamic>);
      final fc = fcRes.data as Map<String, dynamic>;
      final hourly = (fc['hourly'] as List<dynamic>)
          .map((e) => HourlyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final daily = (fc['daily'] as List<dynamic>)
          .map((e) => DailyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        current: () => current,
        hourly: hourly,
        daily: daily,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Search weather for a city name and reload current + forecast.
  Future<void> searchCity(String city) async {
    if (city.trim().isEmpty) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final q = {'city': city.trim()};
      final curRes = await _api.get('/weather', query: q);
      final fcRes = await _api.get('/weather/forecast', query: q);
      final current =
          CurrentWeather.fromJson(curRes.data as Map<String, dynamic>);
      final fc = fcRes.data as Map<String, dynamic>;
      final hourly = (fc['hourly'] as List<dynamic>)
          .map((e) => HourlyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final daily = (fc['daily'] as List<dynamic>)
          .map((e) => DailyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        current: () => current,
        hourly: hourly,
        daily: daily,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>(
  (ref) => WeatherNotifier(ref.watch(apiClientProvider)),
);

