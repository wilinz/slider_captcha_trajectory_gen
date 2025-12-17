import 'package:json_annotation/json_annotation.dart';

part 'captcha_data.g.dart';

@JsonSerializable(explicitToJson: true)
class CaptchaData {
  final String id;
  final int timestamp;
  final ImageInfo bigImage;
  final ImageInfo smallImage;
  final int? yHeight;
  final int canvasLength;
  int? targetDistance;
  List<TrackPoint>? tracks;
  final String? rawJson;

  CaptchaData({
    required this.id,
    required this.timestamp,
    required this.bigImage,
    required this.smallImage,
    this.yHeight,
    required this.canvasLength,
    this.targetDistance,
    this.tracks,
    this.rawJson,
  });

  factory CaptchaData.fromJson(Map<String, dynamic> json) =>
      _$CaptchaDataFromJson(json);

  Map<String, dynamic> toJson() => _$CaptchaDataToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ImageInfo {
  final String file;
  final int width;
  final int height;

  ImageInfo({
    required this.file,
    required this.width,
    required this.height,
  });

  factory ImageInfo.fromJson(Map<String, dynamic> json) =>
      _$ImageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ImageInfoToJson(this);
}

@JsonSerializable(explicitToJson: true)
class TrackPoint {
  final int a; // X position
  final int b; // Y offset
  final int c; // Time interval

  TrackPoint({
    required this.a,
    required this.b,
    required this.c,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> json) =>
      _$TrackPointFromJson(json);

  Map<String, dynamic> toJson() => _$TrackPointToJson(this);
}
