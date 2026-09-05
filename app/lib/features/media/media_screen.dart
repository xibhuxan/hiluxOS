import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/config.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../radio/spectrum_provider.dart';
import '../radio/visualizer_style.dart';
import '../radio/widgets/spectrum_visualizer.dart';
import 'media_provider.dart';
import 'models/media_folder.dart';
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

  /// What the center now-playing panel shows: 'album' = the track's cover
  /// art (folder cover or ffmpeg-extracted embedded art), 'spectrum' = the
  /// shared spectrum visualizer with real FFT data from the backend.
  _NowPlayingMode _mode = _NowPlayingMode.album;

  /// The track id the spectrum pipeline is currently analysing (mirrors
  /// `spectrumProvider`'s URL so we only start/stop it on real changes).
  String? _spectrumTrackId;

  @override
  void dispose() {
    // The visualizer only runs while the Media screen exists: kill the
    // backend ffmpeg pipeline when leaving the screen with spectrum on.
    if (_mode == _NowPlayingMode.spectrum) {
      ref.read(spectrumProvider.notifier).stop();
    }
    _query.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mediaProvider.notifier).loadTracks();
      ref.read(mediaProvider.notifier).loadFolders();
    });
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

    // Track changes while the visualizer is showing: re-point the backend
    // spectrum pipeline at the new track's stream URL (same lazy pattern as
    // radio's provider, but driven from the screen since the visualizer is
    // a Media-screen-only concern).
    ref.listen<MediaState>(mediaProvider, (prev, next) {
      final id = next.current?.id;
      if (_mode == _NowPlayingMode.spectrum &&
          id != null &&
          id != _spectrumTrackId) {
        _startSpectrum(id);
      }
    });

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
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Carpetas',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted)),
                    ),
                    // Add a library folder (the backend persists it in the
                    // media_folders table and scans it right away).
                    IconButton(
                      tooltip: 'Añadir carpeta',
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      onPressed: state.foldersBusy ? null : _promptAddFolder,
                    ),
                  ],
                ),
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
                    // One header tile per configured folder root (with a
                    // missing-path warning and a delete action).
                    for (final f in state.folders) _folderSectionTile(state, f),
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

  /// A configured folder root in the rail: basename + missing warning (⚠ +
  /// "no disponible") + delete action. Roots are informative in v1 — folder
  /// browsing stays in the relPath tree below (the backend keeps relPath
  /// relative to the folder that contains the file).
  Widget _folderSectionTile(MediaState state, MediaFolder folder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: ListTile(
            dense: true,
            leading: Icon(
              folder.exists ? Icons.source_outlined : Icons.warning_amber_rounded,
              size: 20,
              color: folder.exists ? AppColors.muted : AppColors.danger,
            ),
            title: Text(
              folder.exists ? folder.label : '${folder.label} (no disponible)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: folder.exists
                  ? null
                  : const TextStyle(color: AppColors.danger),
            ),
            // Delete with confirm — removing purges the folder's tracks
            // from the index (files on disk stay untouched).
            trailing: IconButton(
              tooltip: 'Quitar carpeta',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.muted),
              onPressed: state.foldersBusy ? null : () => _confirmRemoveFolder(folder),
            ),
            onTap: () {
              if (!folder.exists) {
                // Explain the warning; missing folders can't be browsed
                // (the scanner skips them until they reappear).
                _showSnack('Ruta no disponible: ${folder.path}');
              }
            },
          ),
        ),
        if (!folder.exists)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: Text('ruta no disponible: ${folder.path}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.danger)),
          ),
      ],
    );
  }

  /// The "＋ Añadir carpeta" dialog: a plain TextField (the shell-level
  /// VirtualKeypad attaches to any focused text field automatically).
  Future<void> _promptAddFolder() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Añadir carpeta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '/ruta/absoluta/a/la/carpeta',
            labelText: 'Ruta absoluta',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (path == null || path.isEmpty) return;
    final err = await ref.read(mediaProvider.notifier).addFolder(path);
    if (err != null) _showSnack(err);
  }

  /// Delete confirm: purges the folder's tracks from the index.
  Future<void> _confirmRemoveFolder(MediaFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar carpeta'),
        content: Text(
            'Se quitará "${folder.label}" de la biblioteca y sus canciones '
            'se eliminarán del índice (los archivos no se tocan).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await ref.read(mediaProvider.notifier).removeFolder(folder.id);
    if (err != null) _showSnack(err);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              // Two now-playing modes, picked from the controls-row popup:
              // album cover (default) or the shared spectrum visualizer.
              child: _mode == _NowPlayingMode.spectrum
                  ? SpectrumVisualizer(
                      active: state.isPlaying,
                      showStyleButton: false,
                    )
                  : state.current == null
                      ? Center(
                          child: Icon(
                            state.isPlaying
                                ? Icons.graphic_eq
                                : Icons.library_music_outlined,
                            size: 120,
                            color: state.isPlaying
                                ? AppColors.primary
                                : AppColors.muted,
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
        // Now-playing mode picker: album art (this screen's own work) or any
        // of the shared spectrum visualizer styles + random. Same popup
        // pattern as Radio's style picker.
        _modeMenuButton(),
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

  // ── Now-playing mode picker (album art vs spectrum styles) ──────────────

  /// Popup button offering the two center-panel modes: "Álbum" (the track's
  /// cover, default) and every spectrum visualizer style (plus "Aleatorio",
  /// which rotates styles every 12 s — the shared behavior from Radio).
  Widget _modeMenuButton() {
    final style = ref.watch(visualizerStyleProvider);
    // The button icon mirrors the active mode: album icon for covers, the
    // current style's icon (or shuffle) for the visualizer.
    final icon = _mode == _NowPlayingMode.album
        ? Icons.album
        : (style.random ? Icons.shuffle : style.style.icon);
    return PopupMenuButton<String>(
      tooltip: 'Vista de reproducción',
      icon: Icon(icon, color: AppColors.muted, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.surfaceVariant,
      onSelected: (v) {
        if (v == 'album') {
          setState(() => _mode = _NowPlayingMode.album);
          _stopSpectrum();
        } else if (v == 'random') {
          setState(() => _mode = _NowPlayingMode.spectrum);
          ref.read(visualizerStyleProvider.notifier).setRandom();
          _startSpectrumForCurrent();
        } else {
          setState(() => _mode = _NowPlayingMode.spectrum);
          ref
              .read(visualizerStyleProvider.notifier)
              .setStyle(VisualizerStyle.values.byName(v));
          _startSpectrumForCurrent();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'album',
          child: _menuRow(Icons.album, 'Álbum',
              selected: _mode == _NowPlayingMode.album),
        ),
        const PopupMenuDivider(),
        for (final s in VisualizerStyle.values)
          PopupMenuItem(
            value: s.name,
            child: _menuRow(s.icon, s.label,
                selected:
                    _mode == _NowPlayingMode.spectrum && s == style.style && !style.random),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'random',
          child: _menuRow(Icons.shuffle, 'Aleatorio',
              selected: _mode == _NowPlayingMode.spectrum && style.random),
        ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label, {required bool selected}) {
    return Row(children: [
      Icon(icon,
          size: 18, color: selected ? AppColors.primary : AppColors.muted),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: selected ? AppColors.primary : AppColors.onBackground)),
    ]);
  }

  /// Start (or re-point) the backend spectrum pipeline at the current
  /// track's stream. No-op without a current track.
  void _startSpectrumForCurrent() {
    final id = ref.read(mediaProvider).current?.id;
    if (id != null) _startSpectrum(id);
  }

  void _startSpectrum(String trackId) {
    // Track what we started so the ref.listen track-change handler can
    // detect real changes (and skip when the id merely re-appears).
    _spectrumTrackId = trackId;
    // The backend's SpectrumService is URL-generic (radio streams, local
    // files — anything ffmpeg can read), so the media stream endpoint
    // plugs straight in without backend changes.
    ref
        .read(spectrumProvider.notifier)
        .start('${AppConfig.restBase}/media/stream/$trackId');
  }

  /// Stop the backend pipeline when leaving spectrum mode. The listenerId
  /// is per-app-session so this can't kill radio's own analysis.
  void _stopSpectrum() {
    _spectrumTrackId = null;
    ref.read(spectrumProvider.notifier).stop();
  }
}

/// What the Media center panel shows above the seek bar.
enum _NowPlayingMode { album, spectrum }
