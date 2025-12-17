// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'captcha_data_v2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CaptchaDataV2 _$CaptchaDataV2FromJson(Map<String, dynamic> json) =>
    CaptchaDataV2(
      id: json['id'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      bigImage: json['bigImage'] == null
          ? null
          : ImageInfo.fromJson(json['bigImage'] as Map<String, dynamic>),
      smallImage: json['smallImage'] == null
          ? null
          : ImageInfo.fromJson(json['smallImage'] as Map<String, dynamic>),
      yHeight: (json['yHeight'] as num?)?.toInt(),
      canvasLength: (json['canvasLength'] as num).toInt(),
      targetDistance: (json['targetDistance'] as num?)?.toInt(),
      timerTracks: (json['timerTracks'] as List<dynamic>?)
          ?.map((e) => RawTrackPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      eventTracks: (json['eventTracks'] as List<dynamic>?)
          ?.map((e) => RawTrackPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] == null
          ? null
          : TrajectoryMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            ),
      rawJson: json['rawJson'] as String?,
    );

Map<String, dynamic> _$CaptchaDataV2ToJson(CaptchaDataV2 instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp,
      'bigImage': instance.bigImage?.toJson(),
      'smallImage': instance.smallImage?.toJson(),
      'yHeight': instance.yHeight,
      'canvasLength': instance.canvasLength,
      'targetDistance': instance.targetDistance,
      'timerTracks': instance.timerTracks?.map((e) => e.toJson()).toList(),
      'eventTracks': instance.eventTracks?.map((e) => e.toJson()).toList(),
      'metadata': instance.metadata?.toJson(),
      'rawJson': instance.rawJson,
    };

RawTrackPoint _$RawTrackPointFromJson(Map<String, dynamic> json) =>
    RawTrackPoint(
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
      interval: (json['interval'] as num).toInt(),
    );

Map<String, dynamic> _$RawTrackPointToJson(RawTrackPoint instance) =>
    <String, dynamic>{
      'x': instance.x,
      'y': instance.y,
      'timestamp': instance.timestamp,
      'interval': instance.interval,
    };

TrajectoryMetadata _$TrajectoryMetadataFromJson(Map<String, dynamic> json) =>
    TrajectoryMetadata(
      totalTime: (json['totalTime'] as num).toInt(),
      timerPointCount: (json['timerPointCount'] as num).toInt(),
      eventPointCount: (json['eventPointCount'] as num).toInt(),
      avgEventInterval: (json['avgEventInterval'] as num).toDouble(),
      samplingRate: (json['samplingRate'] as num).toDouble(),
    );

Map<String, dynamic> _$TrajectoryMetadataToJson(TrajectoryMetadata instance) =>
    <String, dynamic>{
      'totalTime': instance.totalTime,
      'timerPointCount': instance.timerPointCount,
      'eventPointCount': instance.eventPointCount,
      'avgEventInterval': instance.avgEventInterval,
      'samplingRate': instance.samplingRate,
    };
