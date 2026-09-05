// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/media/widgets/folder_picker_dialog.dart';

/// Fake filesystem for the picker: a small tree plus an unreadable branch
/// (readable:false) and dot-directories the picker must never show.
FolderBrowse _browse(String? path) {
  switch (path) {
    case null:
      return const FolderBrowse(
        path: '/',
        parent: null,
        home: '/home/xibhu',
        readable: true,
        dirs: [
          FolderEntry(name: 'home', path: '/home'),
          FolderEntry(name: 'media', path: '/media'),
        ],
      );
    case '/home':
      return const FolderBrowse(
        path: '/home',
        parent: '/',
        home: '/home/xibhu',
        readable: true,
        dirs: [FolderEntry(name: 'xibhu', path: '/home/xibhu')],
      );
    case '/home/xibhu':
      return const FolderBrowse(
        path: '/home/xibhu',
        parent: '/home',
        home: '/home/xibhu',
        readable: true,
        dirs: [FolderEntry(name: 'Música', path: '/home/xibhu/Música')],
      );
    case '/home/xibhu/Música':
      return const FolderBrowse(
        path: '/home/xibhu/Música',
        parent: '/home/xibhu',
        home: '/home/xibhu',
        readable: true,
        dirs: [],
      );
    case '/media':
      // Exists but the backend can't list it (EACCES on the Pi).
      return const FolderBrowse(
        path: '/media',
        parent: '/',
        home: '/home/xibhu',
        readable: false,
        dirs: [],
      );
    default:
      throw Exception('path not in fake tree');
  }
}

/// Realistic harness: the picker is opened via showDialog (like the media
/// screen does) and its popped value is captured.
Future<void> _openPicker(WidgetTester tester, List<String?> results) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        folderBrowseFnProvider.overrideWith(
          (ref) =>
              (path) async => _browse(path),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  results.add(
                    await showDialog<String>(
                      context: context,
                      builder: (_) => const FolderPickerDialog(),
                    ),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picker navigates directories and pops the selected path', (
    tester,
  ) async {
    final results = <String?>[];
    await _openPicker(tester, results);

    // Starts at the filesystem root.
    expect(find.text('/'), findsOneWidget);

    // Descend: root → home → xibhu. Dot-directories are never offered.
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('/home'), findsOneWidget);
    expect(find.text('.cache'), findsNothing);

    await tester.tap(find.text('xibhu'));
    await tester.pumpAndSettle();
    expect(find.text('/home/xibhu'), findsOneWidget);

    // Into the (empty) Música folder → the empty-hint shows, and the
    // "Inicio" chip jumps back home from there.
    await tester.tap(find.text('Música'));
    await tester.pumpAndSettle();
    expect(find.text('No hay subcarpetas aquí'), findsOneWidget);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('/home/xibhu'), findsOneWidget);

    // Confirming pops with the current directory path.
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir esta carpeta'));
    await tester.pumpAndSettle();
    expect(find.text('Añadir carpeta'), findsNothing);
    expect(results, equals(['/home/xibhu']));
  });

  testWidgets('picker shows the permissions hint on an unreadable directory', (
    tester,
  ) async {
    final results = <String?>[];
    await _openPicker(tester, results);

    await tester.tap(find.text('media'));
    await tester.pumpAndSettle();

    expect(find.text('Sin permisos para leer esta carpeta'), findsOneWidget);
  });

  testWidgets('picker shows the retry row when a browse call fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          folderBrowseFnProvider.overrideWith(
            (ref) => (path) async {
              if (path == null) return _browse(null);
              throw Exception('boom');
            },
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showDialog<String>(
                    context: context,
                    builder: (_) => const FolderPickerDialog(),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // Root loaded fine; tapping a child makes the browse call fail → the
    // error + retry row shows instead of crashing.
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo leer esta carpeta'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
