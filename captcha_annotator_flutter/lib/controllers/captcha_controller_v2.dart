import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/captcha_data_v2.dart';

/// 改进版控制器 - 双序列采集
class CaptchaControllerV2 extends GetxController {
  // 常量配置
  static const double canvasWidth = 280;
  static const double sliderBtnWidth = 40;
  static const double maxMove = canvasWidth - sliderBtnWidth;

  // 定时器采样间隔（可配置：1ms, 5ms, 10ms）
  static const int timerInterval = 5; // 推荐5ms，200Hz采样率

  // UI状态
  var isDragging = false.obs;
  var moveLength = 0.0.obs;

  // 序列1：定时器采样的真实轨迹（均匀采样）
  final RxList<RawTrackPoint> timerTracks = <RawTrackPoint>[].obs;

  // 序列2：事件触发的轨迹（系统采样）
  final RxList<RawTrackPoint> eventTracks = <RawTrackPoint>[].obs;

  // 内部状态
  double _startX = 0;
  double _startY = 0;
  double _initialMoveLength = 0;
  DateTime? _dragStartTime;
  Timer? _samplingTimer;

  // 当前位置（供定时器读取）
  double _currentX = 0;
  double _currentY = 0;

  /// 开始拖动
  void handleDragStart(double startX, double startY) {
    isDragging.value = true;
    _startX = startX;
    _startY = startY;
    _currentX = startX;
    _currentY = startY;
    _initialMoveLength = moveLength.value;
    _dragStartTime = DateTime.now();

    // 清空轨迹
    timerTracks.clear();
    eventTracks.clear();

    // 记录起点（两个序列都记录）
    final startPoint = RawTrackPoint(
      x: 0,
      y: 0,
      timestamp: 0,
      interval: 0,
    );
    timerTracks.add(startPoint);
    eventTracks.add(startPoint);

    // 启动定时器采样
    _startTimerSampling();
  }

  /// 拖动更新
  void handleDragUpdate(double currentX, double currentY) {
    if (!isDragging.value) return;

    // 更新当前位置（供定时器读取）
    _currentX = currentX;
    _currentY = currentY;

    // 计算新位置
    final deltaX = currentX - _startX;
    final newPosition = (_initialMoveLength + deltaX).clamp(0.0, maxMove);
    moveLength.value = newPosition;

    // 记录事件序列
    _recordEventPoint(currentX, currentY, newPosition);
  }

  /// 拖动结束
  void handleDragEnd(double endX, double endY) {
    if (!isDragging.value) return;

    // 停止定时器
    _stopTimerSampling();

    // 记录结束点
    _currentX = endX;
    _currentY = endY;
    final deltaX = endX - _startX;
    final newPosition = (_initialMoveLength + deltaX).clamp(0.0, maxMove);

    _recordEventPoint(endX, endY, newPosition);

    isDragging.value = false;

    // 输出统计信息
    debugPrint('=== 采集完成 ===');
    debugPrint('定时器采样点: ${timerTracks.length}');
    debugPrint('事件触发点: ${eventTracks.length}');
    debugPrint('总时长: ${timerTracks.isNotEmpty ? timerTracks.last.timestamp : 0}ms');
  }

  /// 启动定时器采样
  void _startTimerSampling() {
    _samplingTimer = Timer.periodic(
      Duration(milliseconds: timerInterval),
      (timer) {
        if (!isDragging.value) {
          timer.cancel();
          return;
        }

        // 记录当前真实位置
        _recordTimerPoint();
      },
    );
  }

  /// 停止定时器采样
  void _stopTimerSampling() {
    _samplingTimer?.cancel();
    _samplingTimer = null;
  }

  /// 记录定时器采样点（均匀采样）
  void _recordTimerPoint() {
    if (_dragStartTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_dragStartTime!).inMilliseconds;

    final deltaX = _currentX - _startX;
    final newPosition = (_initialMoveLength + deltaX).clamp(0.0, maxMove);
    final offsetY = (_currentY - _startY).round();

    final interval = timerTracks.isEmpty ? 0 : elapsed - timerTracks.last.timestamp;

    final point = RawTrackPoint(
      x: newPosition.round(),
      y: offsetY,
      timestamp: elapsed,
      interval: interval,
    );

    timerTracks.add(point);
  }

  /// 记录事件触发点（系统采样）
  void _recordEventPoint(double currentX, double currentY, double position) {
    if (_dragStartTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_dragStartTime!).inMilliseconds;

    final offsetY = (currentY - _startY).round();

    final interval = eventTracks.isEmpty ? 0 : elapsed - eventTracks.last.timestamp;

    final point = RawTrackPoint(
      x: position.round(),
      y: offsetY,
      timestamp: elapsed,
      interval: interval,
    );

    eventTracks.add(point);
  }

  /// 导出数据（V2格式）
  CaptchaDataV2 exportData({
    required String id,
    required int canvasLength,
    required int targetDistance,
  }) {
    // 计算元数据
    final metadata = _calculateMetadata();

    return CaptchaDataV2(
      id: id,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      canvasLength: canvasLength,
      targetDistance: targetDistance,
      timerTracks: timerTracks.toList(),
      eventTracks: eventTracks.toList(),
      metadata: metadata,
    );
  }

  /// 计算轨迹元数据
  TrajectoryMetadata _calculateMetadata() {
    if (timerTracks.isEmpty || eventTracks.isEmpty) {
      return TrajectoryMetadata(
        totalTime: 0,
        timerPointCount: 0,
        eventPointCount: 0,
        avgEventInterval: 0.0,
        samplingRate: 0.0,
      );
    }

    // 总时长
    final totalTime = timerTracks.last.timestamp;

    // 平均事件间隔
    double avgEventInterval = 0.0;
    if (eventTracks.length > 1) {
      final totalInterval = eventTracks.skip(1).fold<int>(
        0, (sum, p) => sum + p.interval,
      );
      avgEventInterval = totalInterval / (eventTracks.length - 1);
    }

    // 实际采样率
    final samplingRate = timerTracks.length / (totalTime / 1000.0); // Hz

    return TrajectoryMetadata(
      totalTime: totalTime,
      timerPointCount: timerTracks.length,
      eventPointCount: eventTracks.length,
      avgEventInterval: avgEventInterval,
      samplingRate: samplingRate,
    );
  }

  @override
  void onClose() {
    _stopTimerSampling();
    super.onClose();
  }
}
