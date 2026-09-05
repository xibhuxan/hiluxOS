// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/media/media_provider.dart';
import '../lib/features/media/media_screen.dart';
import '../lib/features/media/models/media_folder.dart';
import '../lib/features/media/models/track.dart';
import '../lib/features/radio/audio_player_provider.dart';
import '../lib/features/radio/widgets/spectrum_visualizer.dart';
import '../lib/features/media/widgets/folder_picker_dialog.dart';

/// MediaNotifier whose side effects are all no-ops: the real AudioPlayer is
/// never instantiated (play/attach overridden without calling super) and no
/// HTTP happens (loadTracks overridden).
class _FakeNotifier extends MediaNotifier {
  _FakeNotifier() : super(ApiClient(Dio()), AudioPlayerService());

  /// `state` has a protected setter; seeding via a subclass method is legal.
  void seed(MediaState s) => state = s;

  @override
  Future<void> loadTracks() async {}
  @override
  Future<void> loadFolders() async {}
  @override
  Future<void> scan() async {}
  @override
  Future<void> play(Track track, {List<Track>? fromQueue}) async {}
  @override
  void attachPlayerListeners() {}
}

Widget _wrap(MediaState state) {
  final notifier = _FakeNotifier()..seed(state);
  return ProviderScope(
    overrides: [
      mediaProvider.overrideWith((ref) => notifier),
      // No HTTP in tests: the folder picker gets a fake one-level tree.
      folderBrowseFnProvider.overrideWith(
        (ref) =>
            (path) async => const FolderBrowse(
              path: '/',
              parent: null,
              home: '/home',
              readable: true,
              dirs: [FolderEntry(name: 'home', path: '/home')],
            ),
      ),
    ],
    child: const MaterialApp(home: MediaScreen()),
  );
}

void main() {
  testWidgets('empty library shows the scan hint', (tester) async {
    await tester.pumpWidget(_wrap(MediaState()));
    await tester.pumpAndSettle();
    expect(
      find.text('Biblioteca vacía — pulsa ↻ para escanear'),
      findsOneWidget,
    );
  });

  testWidgets('tracks render with title and duration', (tester) async {
    final track = Track(
      id: 't1',
      title: 'Test Tone A',
      artist: 'Hilux Soundcheck',
      durationSec: 5,
    );
    await tester.pumpWidget(
      _wrap(MediaState(tracks: [track], duration: const Duration(seconds: 5))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Tone A'), findsOneWidget);
    // "0:05" appears twice: the row's duration label and the seek-bar total.
    expect(find.text('0:05'), findsNWidgets(2));
  });

  testWidgets('current track shows as selected in the list', (tester) async {
    final track = Track(id: 't1', title: 'Test Tone A', durationSec: 5);
    await tester.pumpWidget(
      _wrap(
        MediaState(
          tracks: [track],
          current: track,
          duration: const Duration(seconds: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The seek bar labels render when a track is current.
    expect(find.text('0:00'), findsWidgets);
  });

  testWidgets('folder rail derives folders from relPath and filters on tap', (
    tester,
  ) async {
    // The folder rail needs a wide surface (>=980px) to fit; the car screen
    // is 1280 wide.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracks = [
      Track(id: 't1', title: 'Root A', durationSec: 5, relPath: 'a.mp3'),
      Track(id: 't2', title: 'Rock B', durationSec: 5, relPath: 'Rock/b.mp3'),
      Track(id: 't3', title: 'Jazz C', durationSec: 5, relPath: 'Jazz/c.mp3'),
    ];
    await tester.pumpWidget(_wrap(MediaState(tracks: tracks)));
    await tester.pumpAndSettle();

    // "Todo" plus one node per top-level folder.
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('Jazz'), findsOneWidget);

    // All tracks visible while "Todo" is selected.
    expect(find.text('Root A'), findsOneWidget);
    expect(find.text('Rock B'), findsOneWidget);

    // Tap a folder → the list shows only that folder's files.
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(find.text('Rock B'), findsOneWidget);
    expect(find.text('Root A'), findsNothing);
    expect(find.text('Jazz C'), findsNothing);

    // Tapping the selected folder again collapses back to "Todo".
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(find.text('Root A'), findsOneWidget);
  });

  testWidgets('nested folders expand through the selected path', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracks = [
      Track(
        id: 't1',
        title: 'Deep One',
        durationSec: 5,
        relPath: 'Artista/Album/deep.mp3',
      ),
      Track(
        id: 't2',
        title: 'Other',
        durationSec: 5,
        relPath: 'Solo/other.mp3',
      ),
    ];
    await tester.pumpWidget(_wrap(MediaState(tracks: tracks)));
    await tester.pumpAndSettle();

    // Only top-level folders are visible before drilling in.
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Album'), findsNothing);

    await tester.tap(find.text('Artista'));
    await tester.pumpAndSettle();
    // The child of the open folder shows; the unrelated tree stays hidden.
    expect(find.text('Album'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget); // still a top-level node
  });

  testWidgets('chevrons collapse and re-open the side panels', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracks = [
      Track(id: 't1', title: 'Root A', durationSec: 5, relPath: 'a.mp3'),
      Track(id: 't2', title: 'Rock B', durationSec: 5, relPath: 'Rock/b.mp3'),
    ];
    await tester.pumpWidget(_wrap(MediaState(tracks: tracks)));
    await tester.pumpAndSettle();

    // The two collapsible columns are the only AnimatedContainers in the
    // tree: first = folder rail, last = library panel. (Their clipped
    // contents stay in the widget tree while collapsed, so the reliable
    // signal is the rendered size itself.)
    double panelWidth(int idx) =>
        tester.getSize(find.byType(AnimatedContainer).at(idx)).width;

    // Both panels open to start.
    expect(panelWidth(0), 292);
    expect(panelWidth(1), 392);

    // Left chevron → the folder rail collapses to zero width.
    await tester.tap(find.byTooltip('Ocultar carpetas'));
    await tester.pumpAndSettle();
    expect(panelWidth(0), 0);

    // And it comes back.
    await tester.tap(find.byTooltip('Mostrar carpetas'));
    await tester.pumpAndSettle();
    expect(panelWidth(0), 292);

    // Right chevron → the library panel collapses.
    await tester.tap(find.byTooltip('Ocultar biblioteca'));
    await tester.pumpAndSettle();
    expect(panelWidth(1), 0);

    await tester.tap(find.byTooltip('Mostrar biblioteca'));
    await tester.pumpAndSettle();
    expect(panelWidth(1), 392);
  });

  testWidgets(
    'view picker switches the center panel between album and spectrum',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tracks = [
        Track(id: 't1', title: 'Root A', durationSec: 5, relPath: 'a.mp3'),
      ];
      await tester.pumpWidget(_wrap(MediaState(tracks: tracks)));
      await tester.pumpAndSettle();

      // Default mode: album icon on the picker button, no visualizer yet.
      expect(find.byIcon(Icons.album), findsOneWidget);
      expect(find.byType(SpectrumVisualizer), findsNothing);

      // Open the picker and switch to a spectrum style.
      await tester.tap(find.byTooltip('Vista de reproducción'));
      await tester.pumpAndSettle();
      expect(find.text('Álbum'), findsOneWidget); // the album entry exists
      await tester.tap(find.text('Barras'));
      // NOTE: no pumpAndSettle from here on — the visualizer's Ticker runs
      // forever, so a fixed-duration pump is the only way to "settle".
      // (Two pumps: the first processes the tap + starts the popup's pop
      // animation, the second lets it finish.)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The center panel now renders the shared visualizer.
      expect(find.byType(SpectrumVisualizer), findsOneWidget);
      expect(find.byIcon(Icons.equalizer), findsOneWidget); // 'bars' style icon

      // Back to album mode. (onSelected fires via Navigator.pop().then(...),
      // so it lands after the pop animation completes — each menu interaction
      // needs its own pump pair plus a trailing one for the setState rebuild.)
      await tester.tap(find.byTooltip('Vista de reproducción'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Álbum'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SpectrumVisualizer), findsNothing);
      expect(find.byIcon(Icons.album), findsOneWidget);
    },
  );

  testWidgets(
    'configured folders render with missing warning and remove confirm',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = MediaState(
        tracks: [
          Track(id: 't1', title: 'Root A', durationSec: 5, relPath: 'a.mp3'),
        ],
        folders: const [
          MediaFolder(id: 'f1', path: '/music', label: 'music', exists: true),
          MediaFolder(
            id: 'f2',
            path: '/usb/musica',
            label: 'musica',
            exists: false,
          ),
        ],
      );
      await tester.pumpWidget(_wrap(state));
      await tester.pumpAndSettle();

      // Present folder shows just its label; missing one gets the warning
      // marker and the explanatory path line.
      expect(find.text('music'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('musica (no disponible)'), findsOneWidget);
      expect(find.text('ruta no disponible: /usb/musica'), findsOneWidget);

      // Tapping the missing folder explains instead of filtering.
      await tester.tap(find.text('musica (no disponible)'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      // Remove flow: confirm dialog first, then the delete button.
      await tester.tap(find.byTooltip('Quitar carpeta').first);
      await tester.pumpAndSettle();
      expect(find.text('Quitar carpeta'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Quitar'));
      await tester.pumpAndSettle();
      // The fake notifier no-ops removeFolder (no HTTP in tests) — nothing
      // more to assert beyond the dialog having been shown.
    },
  );

  testWidgets('add-folder dialog opens the system folder picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(MediaState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir carpeta'));
    await tester.pumpAndSettle();

    // The folder picker replaced the typed-path dialog: it navigates the
    // filesystem instead of showing a TextField.
    expect(find.text('Añadir carpeta'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
    // Cancel closes it without adding anything.
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Añadir carpeta'), findsNothing);
  });
}
