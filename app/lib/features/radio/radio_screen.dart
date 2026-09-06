import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/staggered_entrance.dart';
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

  /// Left column: a vistoso now-playing strip, the spectrum visualizer (full
  /// height — the top bar already shows the `Radio — emisora` title) and
  /// playback controls laid out vertically.
  Widget _leftColumn(RadioState state) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NowPlayingStrip(
            station: state.current,
            isPlaying: state.isPlaying,
          ),
          const SizedBox(height: 12),
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
          // Skeleton rows instead of a bare spinner — keeps the layout
          // stable and hints at the incoming list shape.
          return const SingleChildScrollView(child: ShimmerList(count: 6));
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
        final isCurrent = ref.watch(radioProvider).current?.url == s.url;
        return StaggeredEntrance(
          index: i,
          child: _StationTile(
            station: s,
            isFav: isFav,
            isCurrent: isCurrent,
            onPlay: () => ref.read(radioProvider.notifier).play(s),
            onToggleFavorite: () =>
                ref.read(radioProvider.notifier).toggleFavorite(s),
          ),
        );
      },
    );
  }
}
/// A radio station row: favicon, name, country/codec metadata and the
/// favorite heart. The current station is highlighted, and tapping the
/// heart pops so the gesture feels acknowledged on a touch screen.
class _StationTile extends StatefulWidget {
  const _StationTile({
    required this.station,
    required this.isFav,
    required this.isCurrent,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  final Station station;
  final bool isFav;
  final bool isCurrent;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  @override
  State<_StationTile> createState() => _StationTileState();
}

class _StationTileState extends State<_StationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = Tween(begin: 1.0, end: 1.35).animate(
    CurvedAnimation(parent: _pop, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    return ListTile(
      tileColor: widget.isCurrent
          ? AppColors.primary.withValues(alpha: 0.10)
          : null,
      shape: widget.isCurrent
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.35)),
            )
          : null,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 40,
          child: s.favicon != null && s.favicon!.isNotEmpty
              ? Image.network(
                  s.favicon!,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.radio, color: AppColors.primary),
                )
              : Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.radio,
                      color: AppColors.primary, size: 22),
                ),
        ),
      ),
      title: Text(
        s.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color:
                widget.isCurrent ? AppColors.primary : AppColors.onBackground,
            fontWeight: widget.isCurrent ? FontWeight.w600 : FontWeight.w400),
      ),
      subtitle: Text(
        [
          if (s.country != null) s.country!,
          if (s.codec != null) s.codec!,
        ].join(' · '),
        style: const TextStyle(color: AppColors.muted),
      ),
      trailing: ScaleTransition(
        scale: _scale,
        child: IconButton(
          icon: Icon(
            widget.isFav ? Icons.favorite : Icons.favorite_border,
            color: AppColors.danger,
          ),
          onPressed: () {
            // Pop the heart, then fire the action — instant touch feedback.
            _pop
              ..reset()
              ..forward();
            widget.onToggleFavorite();
          },
        ),
      ),
      onTap: widget.onPlay,
    );
  }
}

/// The now-playing strip above the visualizer: station favicon, name and
/// metadata, plus a pulsing "EN DIRECTO" badge while playing. Renders
/// nothing while no station is selected.
class NowPlayingStrip extends StatefulWidget {
  const NowPlayingStrip({
    super.key,
    required this.station,
    required this.isPlaying,
  });

  final Station? station;
  final bool isPlaying;

  @override
  State<NowPlayingStrip> createState() => _NowPlayingStripState();
}

class _NowPlayingStripState extends State<NowPlayingStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Eager init: dispose() must be safe even when the strip never played
    // (the `_pulse` field would otherwise be created lazily in dispose()).
    _pulse =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.isPlaying) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NowPlayingStrip old) {
    super.didUpdateWidget(old);
    // Play/pause toggles the breathing badge; pause freezes it dimmed.
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _pulse.repeat(reverse: true) : _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.station;
    if (s == null) return const SizedBox.shrink();

    final meta = [
      if (s.country != null) s.country!,
      if (s.codec != null) s.codec!,
      if (s.bitrate != null) '${s.bitrate} kbps',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: s.favicon != null && s.favicon!.isNotEmpty
                    ? Image.network(
                        s.favicon!,
                        errorBuilder: (_, _, _) => const Icon(Icons.radio,
                            color: AppColors.primary, size: 28),
                      )
                    : Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.radio,
                            color: AppColors.primary, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Pulsing red dot + label while live: "EN DIRECTO" fades with
            // the dot so the pair reads as one breathing unit.
            if (widget.isPlaying)
              FadeTransition(
                opacity: _pulse,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EN DIRECTO',
                      style: TextStyle(
                        letterSpacing: 1.2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger.withValues(alpha: 0.9),
                      ),
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
