import 'package:json_annotation/json_annotation.dart';
import 'captcha_data.dart'; // 导入ImageInfo

part 'captcha_data_v2.g.dart';

/// 改进版数据模型 - 双序列设计（真实采样）
@JsonSerializable(explicitToJson: true)
class CaptchaDataV2 {
  final String id;
  final int timestamp;

  // 图片信息（用于数据集标注）
  final ImageInfo? bigImage;
  final ImageInfo? smallImage;
  final int? yHeight;

  final int canvasLength;
  final int? targetDistance;

  // 序列1：定时器采样序列（5ms均匀采样，真实数据！）
  final List<RawTrackPoint>? timerTracks;

  // 序列2：事件触发序列（onPanUpdate触发时的真实采样点）
  final List<RawTrackPoint>? eventTracks;

  // 元数据
  final TrajectoryMetadata? metadata;

  // 原始JSON（保留兼容性）
  final String? rawJson;

  CaptchaDataV2({
    required this.id,
    required this.timestamp,
    this.bigImage,
    this.smallImage,
    this.yHeight,
    required this.canvasLength,
    this.targetDistance,
    this.timerTracks,
    this.eventTracks,
    this.metadata,
    this.rawJson,
  });

  factory CaptchaDataV2.fromJson(Map<String, dynamic> json) =>
      _$CaptchaDataV2FromJson(json);

  Map<String, dynamic> toJson() => _$CaptchaDataV2ToJson(this);
}

/// 轨迹点（适用于两种序列）
@JsonSerializable(explicitToJson: true)
class RawTrackPoint {
  final int x;           // X坐标（相对于画布）
  final int y;           // Y偏移（相对于起始Y）
  final int timestamp;   // 相对时间戳（ms，从拖动开始计算）
  final int interval;    // 距离上一点的时间间隔（ms）

  RawTrackPoint({
    required this.x,
    required this.y,
    required this.timestamp,
    required this.interval,
  });

  factory RawTrackPoint.fromJson(Map<String, dynamic> json) =>
      _$RawTrackPointFromJson(json);

  Map<String, dynamic> toJson() => _$RawTrackPointToJson(this);
}


/// 轨迹元数据
@JsonSerializable(explicitToJson: true)
class TrajectoryMetadata {
  final int totalTime;            // 总时长（ms）
  final int timerPointCount;      // 定时器采样点数量
  final int eventPointCount;      // 事件触发点数量
  final double avgEventInterval;  // 平均事件间隔（ms）
  final double samplingRate;      // 定时器采样率（Hz）

  TrajectoryMetadata({
    required this.totalTime,
    required this.timerPointCount,
    required this.eventPointCount,
    required this.avgEventInterval,
    required this.samplingRate,
  });

  factory TrajectoryMetadata.fromJson(Map<String, dynamic> json) =>
      _$TrajectoryMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$TrajectoryMetadataToJson(this);
}
