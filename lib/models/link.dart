import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'link.g.dart';

@collection
@JsonSerializable()
class Link {
  Id id = Isar.autoIncrement;

  @Index()
  @JsonKey(defaultValue: 'other')
  String type = 'other';
  
  @JsonKey(defaultValue: '')
  String url = '';
  
  String? title;

  Link({this.type = 'other', this.url = '', this.title});

  factory Link.fromMap(Map<String, dynamic> data) => Link(
    type: data['type'] as String? ?? 'other',
    url: data['url'] as String? ?? '',
    title: data['title'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'url': url,
    'title': title,
  };

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
