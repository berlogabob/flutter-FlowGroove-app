import 'package:equatable/equatable.dart';

class SectionSpan extends Equatable {
  const SectionSpan({
    required this.sectionId,
    required this.startBar,
    required this.bars,
  });

  factory SectionSpan.fromJson(Map<String, dynamic> json) => SectionSpan(
    sectionId: json['sectionId'] as String? ?? '',
    startBar: (json['startBar'] as num?)?.toInt() ?? 0,
    bars: (json['bars'] as num?)?.toInt() ?? 0,
  );

  final String sectionId;
  final int startBar;
  final int bars;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sectionId': sectionId,
    'startBar': startBar,
    'bars': bars,
  };

  SectionSpan copyWith({String? sectionId, int? startBar, int? bars}) =>
      SectionSpan(
        sectionId: sectionId ?? this.sectionId,
        startBar: startBar ?? this.startBar,
        bars: bars ?? this.bars,
      );

  @override
  List<Object?> get props => [sectionId, startBar, bars];
}
