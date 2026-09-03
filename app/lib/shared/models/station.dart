class Station {
  final String id;
  final String name;
  final String url;
  final String? favicon;
  final String? country;
  final String? codec;
  final int? bitrate;
  final List<String> tags;

  Station({
    required this.id,
    required this.name,
    required this.url,
    this.favicon,
    this.country,
    this.codec,
    this.bitrate,
    this.tags = const [],
  });

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        favicon: json['favicon'] as String?,
        country: json['country'] as String?,
        codec: json['codec'] as String?,
        bitrate: json['bitrate'] as int?,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      );

  /// Serializes the station for POSTing to the backend (favorites/history).
  /// Note: `id` is intentionally omitted — the backend's ValidationPipe runs
  /// with `forbidNonWhitelisted: true`, and `FavoriteStationDto` has no `id`
  /// field. Sending it would cause a 400 "property id should not exist".
  /// The `id` is generated/managed by the backend (DB or radio-browser API).
  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'favicon': favicon,
        'country': country,
        'codec': codec,
        'bitrate': bitrate,
        'tags': tags,
      };
}