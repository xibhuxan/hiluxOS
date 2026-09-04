/// A local music track from the backend's media library (/media/tracks).
class Track {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? genre;
  final double durationSec;
  final int? trackNo;
  final int? year;
  final int? bitrate;
  final String? codec;
  final int playCount;
  final String? lastPlayedAt;
  /// Path relative to MEDIA_DIR ('' at the library root). Drives the folder
  /// tree view; absent payloads (older backends) default to ''.
  final String relPath;

  Track({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.genre,
    required this.durationSec,
    this.trackNo,
    this.year,
    this.bitrate,
    this.codec,
    this.playCount = 0,
    this.lastPlayedAt,
    this.relPath = '',
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        genre: json['genre'] as String?,
        durationSec: (json['durationSec'] as num).toDouble(),
        trackNo: json['trackNo'] as int?,
        year: json['year'] as int?,
        bitrate: json['bitrate'] as int?,
        codec: json['codec'] as String?,
        playCount: json['playCount'] as int? ?? 0,
        lastPlayedAt: json['lastPlayedAt'] as String?,
        relPath: json['relPath'] as String? ?? '',
      );

  /// The folder containing this file ('' = MEDIA_DIR root).
  String get folderName {
    final i = relPath.lastIndexOf('/');
    return i < 0 ? '' : relPath.substring(0, i);
  }

  /// "[Artist – ] Title", the display form used by list rows and now-playing.
  String get displayName =>
      (artist == null || artist!.isEmpty) ? title : '$artist — $title';

  /// "Album · Genre" or just one of them, for the list row subtitle.
  String get subtitle {
    final parts = [
      if (album != null && album!.isNotEmpty) album!,
      if (genre != null && genre!.isNotEmpty) genre!,
    ];
    return parts.join(' · ');
  }
}
