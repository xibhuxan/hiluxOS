import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// A geocoded place returned by the backend (Nominatim proxy).
class GeoPlace {
  final String name;
  final String displayName;
  final double lat;
  final double lon;

  const GeoPlace({
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory GeoPlace.fromJson(Map<String, dynamic> j) => GeoPlace(
        name: j['name'] as String,
        displayName: j['displayName'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

/// A computed driving route (OSRM proxy).
class RouteInfo {
  final double distanceKm;
  final double durationMin;
  /// GeoJSON coordinate pairs [lon, lat].
  final List<List<double>> geometry;
  final List<String> steps;

  const RouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.geometry,
    this.steps = const [],
  });

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
        distanceKm: (j['distanceKm'] as num).toDouble(),
        durationMin: (j['durationMin'] as num).toDouble(),
        geometry: (j['geometry'] as List<dynamic>? ?? [])
            .map((c) => (c as List<dynamic>)
                .map((n) => (n as num).toDouble())
                .toList())
            .toList(),
        steps: (j['steps'] as List<dynamic>? ?? [])
            .map((s) => (s as Map<String, dynamic>)['instruction'] as String)
            .toList(),
      );
}


/// Immutable snapshot of the maps/navigation feature.
class MapsState {
  /// Current position; default is Madrid (no GPS on the Pi).
  final double lat;
  final double lon;
  final List<GeoPlace> searchResults;
  final GeoPlace? destination;
  final RouteInfo? route;
  final bool searching;
  final bool routing;
  final String? error;

  const MapsState({
    this.lat = 40.4168,
    this.lon = -3.7038,
    this.searchResults = const [],
    this.destination,
    this.route,
    this.searching = false,
    this.routing = false,
    this.error,
  });

  MapsState copyWith({
    double? lat,
    double? lon,
    List<GeoPlace>? searchResults,
    GeoPlace? Function()? destination,
    RouteInfo? Function()? route,
    bool? searching,
    bool? routing,
    String? Function()? error,
  }) =>
      MapsState(
        lat: lat ?? this.lat,
        lon: lon ?? this.lon,
        searchResults: searchResults ?? this.searchResults,
        destination: destination != null ? destination() : this.destination,
        route: route != null ? route() : this.route,
        searching: searching ?? this.searching,
        routing: routing ?? this.routing,
        error: error != null ? error() : this.error,
      );
}

class MapsNotifier extends StateNotifier<MapsState> {
  MapsNotifier(this._api) : super(const MapsState());
  final ApiClient _api;

  /// Search destination places via the backend geocode proxy.
  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    state = state.copyWith(searching: true, error: () => null);
    try {
      final res = await _api.get('/maps/geocode', query: {'q': q});
      final results = (res.data as List<dynamic>)
          .map((e) => GeoPlace.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(searchResults: results, searching: false);
    } catch (_) {
      state = state.copyWith(
        searching: false,
        searchResults: const [],
        error: () => 'No se pudo buscar. Sin conexión con el servidor.',
      );
    }
  }

  /// Pick a search result as the current destination (clears any route).
  void selectDestination(GeoPlace place) {
    state = state.copyWith(
      destination: () => place,
      route: () => null,
      searchResults: const [],
      error: () => null,
    );
  }

  /// Move the "current position" marker (map long-press / default).
  void setPosition(double lat, double lon) {
    state = state.copyWith(lat: lat, lon: lon, route: () => null);
  }

  /// Compute the driving route from current position to the destination.
  Future<void> computeRoute() async {
    final dest = state.destination;
    if (dest == null) return;
    state = state.copyWith(routing: true, error: () => null);
    try {
      final res = await _api.get('/maps/route', query: {
        'from': '${state.lat},${state.lon}',
        'to': '${dest.lat},${dest.lon}',
      });
      state = state.copyWith(
        routing: false,
        route: () => RouteInfo.fromJson(res.data as Map<String, dynamic>),
      );
    } catch (_) {
      state = state.copyWith(
        routing: false,
        route: () => null,
        error: () => 'No se pudo calcular la ruta.',
      );
    }
  }

  /// Clear destination + route and reset the search list.
  void clearRoute() {
    state = state.copyWith(
      destination: () => null,
      route: () => null,
      searchResults: const [],
      error: () => null,
    );
  }
}

final mapsProvider = StateNotifierProvider<MapsNotifier, MapsState>(
  (ref) => MapsNotifier(ref.watch(apiClientProvider)),
);
