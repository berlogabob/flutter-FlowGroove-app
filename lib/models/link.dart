import 'package:json_annotation/json_annotation.dart';

part 'link.g.dart';

@JsonSerializable()
class Link {
  Link({required this.type, required this.url, this.title});

  factory Link.fromJson(Map<String, dynamic> json) => _$LinkFromJson(json);

  @JsonKey(defaultValue: 'other')
  final String type;
  @JsonKey(defaultValue: '')
  final String url;
  final String? title;

  static const String typeChords = 'chords';
  static const String typeDrums = 'drums';
  static const String typeOther = 'other';
  static const String typeSpotify = 'spotify';
  static const String typeTabs = 'tabs';
  static const String typeYoutubeCover = 'youtube_cover';
  static const String typeYoutubeOriginal = 'youtube_original';

  Map<String, dynamic> toJson() => _$LinkToJson(this);
}
