/// Maps a route location to the top-bar title, enriching it with the "now
/// playing" info of the relevant feature. Pure function → unit-testable
/// without timers or player channels. Home (`/`) shows no title.
String? shellTitleFor(
  String location, {
  String? radioStation,
  String? mediaTrack,
}) {
  switch (location) {
    case '/radio':
      return radioStation == null ? 'Radio' : 'Radio — $radioStation';
    case '/media':
      return mediaTrack == null ? 'Media' : 'Media — $mediaTrack';
    case '/system':
      return 'Sistema';
    case '/settings':
      return 'Ajustes';
    case '/vehicle':
      return 'Vehículo';
    case '/equalizer':
      return 'Ecualizador';
    case '/btmedia':
      return 'Bluetooth';
    case '/weather':
      return 'Clima';
    case '/maps':
      return 'Navegación';
    case '/voice':
      return 'Asistente';
    default:
      return null;
  }
}
