// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/layout/shell_title.dart';

void main() {
  test('radio shows plain title with no station, enriched with one', () {
    expect(shellTitleFor('/radio'), 'Radio');
    expect(shellTitleFor('/radio', radioStation: 'Rock FM'), 'Radio — Rock FM');
  });

  test('media shows plain title with no track, enriched with one', () {
    expect(shellTitleFor('/media'), 'Media');
    expect(shellTitleFor('/media', mediaTrack: 'Artista — Canción'), 'Media — Artista — Canción');
  });

  test('other sections keep their fixed titles', () {
    expect(shellTitleFor('/system'), 'Sistema');
    expect(shellTitleFor('/settings'), 'Ajustes');
  });

  test('home has no title even with now-playing info around', () {
    expect(shellTitleFor('/', radioStation: 'X', mediaTrack: 'Y'), isNull);
    expect(shellTitleFor('/splash'), isNull);
  });

  test('radio info never leaks into the media title and vice versa', () {
    expect(shellTitleFor('/media', radioStation: 'Rock FM'), 'Media');
    expect(shellTitleFor('/radio', mediaTrack: 'Canción'), 'Radio');
  });
}
