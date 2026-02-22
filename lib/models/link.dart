import 'package:json_annotation/json_annotation.dart';

part 'link.g.dart';

@JsonSerializable()
class Link {
  @JsonKey(defaultValue: 'other')
  final String type;
  @JsonKey(defaultValue: '')
  final String url;
  final String? title;

  Link({required this.type, required this.url, this.title});

  Map<String, dynamic> toJson() => _$LinkToJson(this);

  factory Link.fromJson(Map<String, dynamic> json) => _$LinkFromJson(json);

  static const String typeYoutubeOriginal = 'youtube_original';
  static const String typeYoutubeCover = 'youtube_cover';
  static const String typeSpotify = 'spotify';
  static const String typeTabs = 'tabs';
  static const String typeDrums = 'drums';
  static const String typeChords = 'chords';
  static const String typeOther = 'other';
}
