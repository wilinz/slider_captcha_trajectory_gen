// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'captcha_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptchaData _$CaptchaDataFromJson(Map<String, dynamic> json) => CaptchaData(
  id: json['id'] as String,
  timestamp: (json['timestamp'] as num).toInt(),
  bigImage: ImageInfo.fromJson(json['bigImage'] as Map<String, dynamic>),
  smallImage: ImageInfo.fromJson(json['smallImage'] as Map<String, dynamic>),
  yHeight: (json['yHeight'] as num?)?.toInt(),
  canvasLength: (json['canvasLength'] as num).toInt(),
  targetDistance: (json['targetDistance'] as num?)?.toInt(),
  tracks: (json['tracks'] as List<dynamic>?)
      ?.map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
      .toList(),
  rawJson: json['rawJson'] as String?,
);

Map<String, dynamic> _$CaptchaDataToJson(CaptchaData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp,
      'bigImage': instance.bigImage.toJson(),
      'smallImage': instance.smallImage.toJson(),
      'yHeight': instance.yHeight,
      'canvasLength': instance.canvasLength,
      'targetDistance': instance.targetDistance,
      'tracks': instance.tracks?.map((e) => e.toJson()).toList(),
      'rawJson': instance.rawJson,
    };

ImageInfo _$ImageInfoFromJson(Map<String, dynamic> json) => ImageInfo(
  file: json['file'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
);

Map<String, dynamic> _$ImageInfoToJson(ImageInfo instance) => <String, dynamic>{
  'file': instance.file,
  'width': instance.width,
  'height': instance.height,
};

TrackPoint _$TrackPointFromJson(Map<String, dynamic> json) => TrackPoint(
  a: (json['a'] as num).toInt(),
  b: (json['b'] as num).toInt(),
  c: (json['c'] as num).toInt(),
);

Map<String, dynamic> _$TrackPointToJson(TrackPoint instance) =>
    <String, dynamic>{'a': instance.a, 'b': instance.b, 'c': instance.c};
