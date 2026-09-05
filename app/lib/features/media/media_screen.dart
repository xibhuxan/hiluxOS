import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/config.dart';
import '../../core/widgets/staggered_entrance.dart';
import 'media_provider.dart';
import 'models/track.dart';

class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});
  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  final _query = TextEditingController();

  /// Side-panel collapse state (same pattern as Radio's search panel):
  /// false → the AnimatedContainer shrinks to 0 width with the panel
  /// contents clipped inside an OverflowBox.
  bool _folderPanelOpen = true;
  bool _libraryPanelOpen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mediaProvider.notifier).loadTracks();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Local (client-side) filter over the loaded library.
  List<Track> _filteredOf(List<Track> tracks) {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return tracks;
    return tracks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            (t.artist?.toLowerCase().contains(q) ?? false) ||
            (t.album?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaProvider);
    return Scaffold(
      // The folder rail only fits on wide surfaces (car screen); narrower
      // windows get the classic two-column layout.
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) ...[_folderColumn(state)],
            Expanded(flex: 5, child: _leftColumn(state)),
            _rightColumn(state),
          ],
        );
      }),
    );
  }

  /// Left rail as a collapsible column: animated 280↔0 width. Same mechanic
  /// as Radio's right panel — AnimatedContainer + clipped OverflowBox so the
  /// contents keep their natural width while the container shrinks.
  Widget _folderColumn(MediaState state) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: _folderPanelOpen ? 292 : 0,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 292,
          maxWidth: 292,
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 292,
            child: Row(
              children: [
                Expanded(child: _folderTree(state)),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Right column (the library) — same collapsible mechanic, 380↔0. The
  /// 12px gutter sits on the inner side, so collapsing leaves the center
  /// panel flush against the screen edge without gaps.
  Widget _rightColumn(MediaState state) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: _libraryPanelOpen ? 392 : 0,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 392,
          maxWidth: 392,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 392,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(child: _libraryPanel(state)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The expanded folder (null = all tracks). Kept as screen state; tapping a
  /// folder selects it, tapping the selected one collapses back to "Todo".
  String? _openFolder;

  /// Flat list of ancestor folders of [dirPath] ("a/b" → ["a", "a/b"]).
  static List<String> _ancestorsOf(String dirPath) {
    if (dirPath.isEmpty) return const [];
    final out = <String>[];
    var p = dirPath;
    while (true) {
      out.add(p);
      final i = p.lastIndexOf('/');
      if (i <= 0) break;
      p = p.substring(0, i);
    }
    return out;
  }

  /// Tracks inside [folder] exactly (not its subfolders).
  List<Track> _tracksIn(List<Track> tracks, String folder) => tracks
      .where((t) => t.folderName == folder)
      .toList();

  /// Left rail: folder tree derived from the loaded library's relPath values.
  /// Tap a folder → the library list shows exactly that folder's tracks (and
  /// the queue/next/previous then run inside that folder). Ancestors of the
  /// open folder are shown expanded; everything else stays collapsed.
  Widget _folderTree(MediaState state) {
    // All folder nodes (ancestors included) → count of files directly inside.
    final counts = <String, int>{};
    for (final t in state.tracks) {
      final f = t.folderName;
      if (f.isEmpty) continue;
      var p = f;
      while (true) {
        if (p == f) counts[p] = (counts[p] ?? 0) + 1;
        counts.putIfAbsent(p, () => 0);
        final i = p.lastIndexOf('/');
        if (i <= 0) break;
        p = p.substring(0, i);
      }
    }
    // Visible nodes: top-level always; deeper ones only when the open path
    // is expanded through their parent.
    final openAncestors = _openFolder == null
        ? const <String>{}
        : _ancestorsOf(_openFolder!).toSet();
    final nodes = counts.keys
        .where((d) =>
            !d.contains('/') ||
            openAncestors.contains(d.substring(0, d.lastIndexOf('/'))))
        .toList()
      ..sort();

    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
                child: Text('Carpetas',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _folderTile(
                      state,
                      label: 'Todo',
                      icon: Icons.library_music,
                      folder: null,
                      count: state.tracks.length,
                      depth: 0,
                    ),
                    for (final d in nodes)
                      _folderTile(
                        state,
                        label: d.split('/').last,
                        icon: d == _openFolder && _hasSubfolder(counts.keys, d)
                            ? Icons.folder_open
                            : Icons.folder_outlined,
                        folder: d,
                        count: counts[d] ?? 0,
                        depth: d.split('/').length,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasSubfolder(Iterable<String> dirs, String d) =>
      dirs.any((x) => x.length > d.length && x.startsWith('$d/'));

  Widget _folderTile(
    MediaState state, {
    required String label,
    required IconData icon,
    required String? folder,
    required int count,
    required int depth,
  }) {
    final selected = _openFolder == folder;
    return Padding(
      padding: EdgeInsets.only(left: 8.0 * depth),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.15),
        leading: Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.muted),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('$count',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        onTap: () => setState(() => _openFolder = selected ? null : folder),
      ),
    );
  }

  /// Left: album art (the protagonist — the top bar already shows
  /// `Media — canción`, so no in-screen title) and a seek bar below.
  Widget _leftColumn(MediaState state) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: state.current == null
                  ? Center(
                      child: Icon(
                        state.isPlaying ? Icons.graphic_eq : Icons.library_music_outlined,
                        size: 120,
                        color: state.isPlaying ? AppColors.primary : AppColors.muted,
                      ),
                    )
                  : _trackArt(
                      state.current!.id,
                      fit: BoxFit.contain,
                      placeholder: _nowPlayingArtPlaceholder(state),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _progressBar(state),
          const SizedBox(height: 12),
          _controlsRow(state),
        ],
      ),
    );
  }

  /// Idle placeholder for the now-playing art card: big music-note icon.
  Widget _nowPlayingArtPlaceholder(MediaState state) {
    return Center(
      child: Icon(
        state.isPlaying ? Icons.graphic_eq : Icons.library_music_outlined,
        size: 120,
        color: state.isPlaying ? AppColors.primary : AppColors.muted,
      ),
    );
  }

  /// The backend art URL for a track id (folder cover or ffmpeg-extracted
  /// embedded art; same host as the REST API).
  static String _artUrl(String id) => '${AppConfig.restBase}/media/tracks/$id/art';

  /// Art image with graceful fallback: 404/no-art → [placeholder].
  Widget _trackArt(String id,
      {BoxFit fit = BoxFit.cover, Widget? placeholder, double? width, double? height}) {
    return Image.network(
      _artUrl(id),
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          placeholder ?? const Icon(Icons.music_note, color: AppColors.muted),
    );
  }

  /// "1:23" label. Durations above an hour keep the hour.
  String _fmt(Duration d) => d.inHours > 0
      ? '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}'
      : '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Widget _progressBar(MediaState state) {
    final totalMs = state.duration.inMilliseconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: totalMs > 0
                ? state.position.inMilliseconds.clamp(0, totalMs).toDouble()
                : 0,
            max: totalMs > 0 ? totalMs.toDouble() : 1,
            onChanged: state.current == null
                ? null
                : (v) => ref
                    .read(mediaProvider.notifier)
                    .seek(Duration(milliseconds: v.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(state.position), style: const TextStyle(color: AppColors.muted)),
              Text(_fmt(state.duration), style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }

  /// Playback controls: prev / play / next, shuffle, stop — flanked by the
  /// panel-collapse chevrons (left = folder rail, right = library), like
  /// Radio's search-panel toggle.
  Widget _controlsRow(MediaState state) {
    final notifier = ref.read(mediaProvider.notifier);
    final wide = MediaQuery.of(context).size.width >= 980;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left chevron: collapse/expand the folder rail (wide surfaces only).
        if (wide)
          IconButton(
            tooltip: _folderPanelOpen ? 'Ocultar carpetas' : 'Mostrar carpetas',
            icon: Icon(
              _folderPanelOpen ? Icons.chevron_left : Icons.chevron_right,
              color: AppColors.onBackground,
              size: 30,
            ),
            onPressed: () => setState(() => _folderPanelOpen = !_folderPanelOpen),
          ),
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_previous),
          onPressed:
              state.current == null ? null : () => notifier.previous(),
        ),
        const SizedBox(width: 16),
        IconButton.filledTonal(
          iconSize: 36,
          icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: state.current == null
              ? null
              : () => state.isPlaying ? notifier.pause() : notifier.resume(),
        ),
        const SizedBox(width: 16),
        IconButton(
          iconSize: 32,
          icon: const Icon(Icons.skip_next),
          onPressed:
              state.current == null ? null : () => notifier.next(),
        ),
        const SizedBox(width: 24),
        IconButton(
          iconSize: 26,
          tooltip: 'Reproducción aleatoria',
          icon: Icon(Icons.shuffle),
          color: state.shuffle ? AppColors.primary : AppColors.muted,
          onPressed: notifier.toggleShuffle,
        ),
        IconButton(
          iconSize: 26,
          icon: const Icon(Icons.stop),
          onPressed: state.current == null ? null : notifier.stop,
        ),
        // Right chevron: collapse/expand the library panel.
        IconButton(
          tooltip: _libraryPanelOpen ? 'Ocultar biblioteca' : 'Mostrar biblioteca',
          icon: Icon(
            _libraryPanelOpen ? Icons.chevron_right : Icons.chevron_left,
            color: AppColors.onBackground,
            size: 30,
          ),
          onPressed: () => setState(() => _libraryPanelOpen = !_libraryPanelOpen),
        ),
      ],
    );
  }

  /// Right: search field, rescan button and the library list.
  Widget _libraryPanel(MediaState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      decoration: const InputDecoration(
                        hintText: 'Buscar en la biblioteca…',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Reescanear biblioteca',
                    icon: state.scanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    onPressed:
                        state.scanning ? null : () => ref.read(mediaProvider.notifier).scan(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(state.error!,
                      style: const TextStyle(color: AppColors.danger)),
                ),
              Expanded(child: _libraryList(state)),
            ],
          ),
        ),
    );
  }

  Widget _libraryList(MediaState state) {
    // "Todo" shows every track; a selected folder shows exactly its files
    // (subfolders stay collapsed — tap them to drill in). Either way the list
    // doubles as the playback queue: tapping a row plays from this list, so
    // next/previous/auto-advance stay inside what you're looking at.
    final visible = _openFolder == null
        ? _filteredOf(state.tracks)
        : _filteredOf(_tracksIn(state.tracks, _openFolder!));
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (visible.isEmpty) {
      return Center(
        child: Text(
          state.tracks.isEmpty
              ? 'Biblioteca vacía — pulsa ↻ para escanear'
              : 'Sin resultados',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final t = visible[i];
        final isCurrent = state.current?.id == t.id;
        return StaggeredEntrance(
          index: i,
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 44,
                child: _trackArt(t.id,
                    placeholder: Icon(
                      isCurrent && state.isPlaying
                          ? Icons.graphic_eq
                          : Icons.music_note,
                      size: 26,
                      color: isCurrent ? AppColors.primary : AppColors.muted,
                    )),
              ),
            ),
            title: Text(t.title,
                style: isCurrent
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null),
            subtitle: t.subtitle.isEmpty
                ? null
                : Text(t.subtitle, style: const TextStyle(color: AppColors.muted)),
            trailing: Text(_fmt(Duration(seconds: t.durationSec.round())),
                style: const TextStyle(color: AppColors.muted)),
            onTap: () => ref.read(mediaProvider.notifier).play(t, fromQueue: visible),
          ),
        );
      },
    );
  }
}
