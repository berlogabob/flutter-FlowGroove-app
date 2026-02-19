class Link {
  final String type;
  final String url;
  final String? title;

  Link({required this.type, required this.url, this.title});

  Map<String, dynamic> toJson() => {'type': type, 'url': url, 'title': title};

  factory Link.fromJson(Map<String, dynamic> json) => Link(
    type: json['type'] ?? 'other',
    url: json['url'] ?? '',
    title: json['title'],
  );

  static const String typeYoutubeOriginal = 'youtube_original';
  static const String typeYoutubeCover = 'youtube_cover';
  static const String typeTabs = 'tabs';
  static const String typeDrums = 'drums';
  static const String typeChords = 'chords';
  static const String typeOther = 'other';
}
