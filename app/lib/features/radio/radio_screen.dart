import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../layout/app_shell.dart';
import '../../shared/models/station.dart';
import 'radio_provider.dart';
import 'widgets/spectrum_visualizer.dart';

class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});
  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

/// Which list source is shown in the right panel.
enum _Source { search, favorites, history }

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final _query = TextEditingController();
  bool _searchPanelOpen = true;
  _Source _source = _Source.search;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radioProvider.notifier).loadFavorites();
      ref.read(radioProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(radioProvider);
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column: now-playing + visualizer + controls ──
          Expanded(flex: 5, child: _leftColumn(state)),
          // ── Right column: search / favorites / history (collapsible) ──
          _rightColumn(state),
        ],
      ),
    );
  }

  /// Left column: spectrum visualizer (full-height protagonist — the top
  /// bar already shows the `Radio — emisora` title, so no in-screen title),
  /// and playback controls laid out vertically.
  Widget _leftColumn(RadioState state) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spectrum visualizer — the protagonist. Fills remaining space.
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SpectrumVisualizer(
                  active: state.isPlaying,
                  showStyleButton: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _controlsRow(state),
        ],
      ),
    );
  }

  /// Playback controls: stop, play/pause, favorite, and panel toggle.
  Widget _controlsRow(RadioState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(
            Icons.stop_circle_outlined,
            color: AppColors.danger,
            size: 36,
          ),
          onPressed: state.current == null
              ? null
              : () => ref.read(radioProvider.notifier).stop(),
        ),
        IconButton(
          iconSize: 56,
          icon: Icon(
            state.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: AppColors.primary,
          ),
          onPressed: state.current == null
              ? null
              : () {
                  final n = ref.read(radioProvider.notifier);
                  state.isPlaying ? n.pause() : n.resume();
                },
        ),
        IconButton(
          icon: Icon(
            state.current != null &&
                    state.favorites.any((s) => s.url == state.current!.url)
                ? Icons.favorite
                : Icons.favorite_border,
            color: AppColors.danger,
            size: 36,
          ),
          onPressed: state.current == null
              ? null
              : () => ref
                    .read(radioProvider.notifier)
                    .toggleFavorite(state.current!),
        ),
        IconButton(
          tooltip: _searchPanelOpen ? 'Ocultar lista' : 'Mostrar lista',
          icon: Icon(
            _searchPanelOpen ? Icons.chevron_right : Icons.chevron_left,
            color: AppColors.onBackground,
            size: 36,
          ),
          onPressed: () => setState(() => _searchPanelOpen = !_searchPanelOpen),
        ),
        // Full-screen spectrum (tap anywhere to exit) — same shared
        // visualizer, full-bleed. Consumer keeps `active` live if playback
        // stops/starts while in full-screen.
        IconButton(
          tooltip: 'Pantalla completa',
          icon: const Icon(Icons.fullscreen, size: 32),
          onPressed: () =>
              context.findAncestorStateOfType<AppShellState>()?.enterFullscreen(
                (context, exit) => Consumer(
                  builder: (context, ref, _) => SpectrumVisualizer(
                    active: ref.watch(radioProvider).isPlaying,
                    showStyleButton: true,
                  ),
                ),
                // The panel surface tone as backdrop — on pure black the
                // painters' translucent colors read darker than in the Card.
                background: AppColors.surface,
              ),
        ),
      ],
    );
  }

  /// Right column: the search / favorites / history panel. Animated so it
  /// collapses to zero width, giving the visualizer full width.
  Widget _rightColumn(RadioState state) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: _searchPanelOpen ? 360 : 0,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 360,
          maxWidth: 360,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 360, child: _searchPanel(state)),
        ),
      ),
    );
  }

  /// The search panel contents: compact source selector + search field + list.
  Widget _searchPanel(RadioState state) {
    return Card(
      margin: const EdgeInsets.only(left: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _sourceSelector(),
            const SizedBox(height: 12),
            if (_source == _Source.search) ...[
              TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => ref.read(radioProvider.notifier).search(v),
                decoration: InputDecoration(
                  hintText: 'Buscar emisoras…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () =>
                        ref.read(radioProvider.notifier).search(_query.text),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(child: _sourceList(state)),
          ],
        ),
      ),
    );
  }

  /// Compact segmented button for switching between Search / Favorites / History.
  Widget _sourceSelector() {
    return SegmentedButton<_Source>(
      segments: const [
        ButtonSegment(
          value: _Source.search,
          icon: Icon(Icons.search, size: 18),
        ),
        ButtonSegment(
          value: _Source.favorites,
          icon: Icon(Icons.star, size: 18),
        ),
        ButtonSegment(
          value: _Source.history,
          icon: Icon(Icons.history, size: 18),
        ),
      ],
      selected: {_source},
      onSelectionChanged: (s) => setState(() => _source = s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -3, vertical: -2),
      ),
    );
  }

  /// Renders the list for the currently selected source.
  Widget _sourceList(RadioState state) {
    switch (_source) {
      case _Source.search:
        if (state.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) return Center(child: Text(state.error!));
        return _listTab(state.searchResults, emptyText: 'Escribe para buscar');
      case _Source.favorites:
        return _listTab(state.favorites, emptyText: 'Sin favoritos');
      case _Source.history:
        return _listTab(state.history, emptyText: 'Sin historial');
    }
  }

  Widget _listTab(List<Station> stations, {required String emptyText}) {
    if (stations.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: AppColors.muted)),
      );
    }
    return ListView.builder(
      itemCount: stations.length,
      itemBuilder: (context, i) {
        final s = stations[i];
        final isFav = ref
            .watch(radioProvider)
            .favorites
            .any((f) => f.url == s.url);
        return ListTile(
          leading: s.favicon != null && s.favicon!.isNotEmpty
              ? Image.network(
                  s.favicon!,
                  width: 40,
                  height: 40,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.radio, color: AppColors.primary),
                )
              : const Icon(Icons.radio, color: AppColors.primary),
          title: Text(s.name),
          subtitle: Text(
            [
              if (s.country != null) s.country!,
              if (s.codec != null) s.codec!,
            ].join(' · '),
            style: const TextStyle(color: AppColors.muted),
          ),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: AppColors.danger,
            ),
            onPressed: () => ref.read(radioProvider.notifier).toggleFavorite(s),
          ),
          onTap: () => ref.read(radioProvider.notifier).play(s),
        );
      },
    );
  }
}
