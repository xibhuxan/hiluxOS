import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/colors.dart';
import 'maps_provider.dart';

/// Maps/navigation screen: interactive OSM map + destination search + routing.
class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapsProvider);
    final notifier = ref.read(mapsProvider.notifier);

    return Column(
      children: [
        _SearchBar(
          controller: _searchController,
          state: state,
          notifier: notifier,
        ),
        Expanded(
          child: Stack(
            children: [
              _OsmMap(state: state, mapController: _mapController),
              _ZoomControls(mapController: _mapController),
              if (state.error != null)
                _ErrorBanner(
                  message: state.error!,
                  onRetry: () {
                    if (state.destination != null) {
                      notifier.computeRoute();
                    } else {
                      notifier.search(_searchController.text);
                    }
                  },
                ),
              if (state.route != null && state.destination != null)
                _RoutePanel(state: state, notifier: notifier),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.state,
    required this.notifier,
  });
  final TextEditingController controller;
  final MapsState state;
  final MapsNotifier notifier;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            style: const TextStyle(color: AppColors.onBackground, fontSize: 14),
            textInputAction: TextInputAction.search,
            onSubmitted: widget.notifier.search,
            decoration: InputDecoration(
              hintText: 'Buscar destino…',
              hintStyle: const TextStyle(color: AppColors.muted),
              prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
              suffixIcon: widget.state.searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
            ),
          ),
          if (widget.state.searchResults.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.state.searchResults.length,
                itemBuilder: (context, i) {
                  final p = widget.state.searchResults[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place, color: AppColors.primary),
                    title: Text(p.name,
                        style: const TextStyle(color: AppColors.onBackground)),
                    subtitle: Text(
                      p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    onTap: () {
                      widget.notifier.selectDestination(p);
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          if (widget.state.destination != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Destino: ${widget.state.destination!.name}',
                      style: const TextStyle(color: AppColors.onBackground),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: widget.state.routing
                        ? null
                        : widget.notifier.computeRoute,
                    icon: widget.state.routing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.directions, size: 18),
                    label: Text(widget.state.routing ? 'Calculando…' : 'Cómo llegar'),
                  ),
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class _OsmMap extends StatelessWidget {
  const _OsmMap({required this.state, required this.mapController});
  final MapsState state;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final current = LatLng(state.lat, state.lon);
    final dest = state.destination;
    final routePoints = state.route
            ?.geometry
            .map((c) => LatLng(c[1], c[0]))
            .toList() ??
        const <LatLng>[];

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: current,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hiluxos.app',
        ),
        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 4,
                color: AppColors.primary,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: current,
              width: 32,
              height: 32,
              child: const Icon(Icons.my_location,
                  color: AppColors.primary, size: 28),
            ),
            if (dest != null)
              Marker(
                point: LatLng(dest.lat, dest.lon),
                width: 36,
                height: 36,
                child: const Icon(Icons.place, color: AppColors.danger, size: 34),
              ),
          ],
        ),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.mapController});
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: Column(
        children: [
          _ZoomButton(
            icon: Icons.add,
            onPressed: () {
              final cam = mapController.camera;
              mapController.move(cam.center, cam.zoom + 1);
            },
          ),
          const SizedBox(height: 8),
          _ZoomButton(
            icon: Icons.remove,
            onPressed: () {
              final cam = mapController.camera;
              mapController.move(cam.center, cam.zoom - 1);
            },
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.onBackground),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(color: AppColors.onBackground)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.state, required this.notifier});
  final MapsState state;
  final MapsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final route = state.route!;
    return Positioned(
      bottom: 12,
      left: 12,
      right: 76,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route, color: AppColors.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_fmtKm(route.distanceKm)} · ${_fmtMin(route.durationMin)}',
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: notifier.clearRoute,
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    tooltip: 'Cerrar ruta',
                  ),
                ],
              ),
              if (route.steps.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  route.steps.take(2).join(' → '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtKm(double km) =>
      km >= 10 ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';

  static String _fmtMin(double min) {
    if (min < 60) return '${min.toStringAsFixed(0)} min';
    final h = (min / 60).floor();
    final m = (min - h * 60).round();
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }
}

