import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/captcha_data_v2.dart';

/// V2数据集标注控制器 - 结合数据集加载和双序列采集
class CaptchaAnnotatorControllerV2 extends GetxController {
  final String datasetPath;

  CaptchaAnnotatorControllerV2({required this.datasetPath});

  // 常量配置
  static const double canvasWidth = 280;
  static const double sliderBtnWidth = 40;
  static const double maxMove = canvasWidth - sliderBtnWidth;
  static const int timerInterval = 20; // 重采样间隔：20ms

  // 数据集状态
  final metadataFiles = <String>[].obs;
  final currentIndex = 0.obs;
  final Rx<CaptchaDataV2?> currentData = Rx<CaptchaDataV2?>(null);

  // UI状态
  var isDragging = false.obs;
  var moveLength = 0.0.obs;

  // 双序列轨迹
  final RxList<RawTrackPoint> timerTracks = <RawTrackPoint>[].obs;    // 重采样后的均匀序列
  final RxList<RawTrackPoint> eventTracks = <RawTrackPoint>[].obs;    // 原始事件序列（无防抖）

  // 内部状态
  double _startX = 0;
  double _startY = 0;
  double _initialMoveLength = 0;
  DateTime? _dragStartTime;

  @override
  void onInit() {
    super.onInit();
    loadMetadataFiles();
  }

  @override
  void onClose() {
    super.onClose();
  }

  /// 加载数据集元数据文件列表
  Future<void> loadMetadataFiles() async {
    try {
      final metadataDir = Directory('$datasetPath/metadata');
      if (!await metadataDir.exists()) {
        Get.snackbar('错误', '元数据目录不存在');
        return;
      }

      final files = await metadataDir
          .list()
          .where((entity) => entity.path.endsWith('.json'))
          .map((entity) => entity.path)
          .toList();

      metadataFiles.value = files..sort();
      if (metadataFiles.isNotEmpty) {
        await loadCaptcha(0);
      }
    } catch (e) {
      Get.snackbar('错误', '加载元数据文件失败: $e');
    }
  }

  /// 加载指定索引的验证码数据
  Future<void> loadCaptcha(int index) async {
    if (index < 0 || index >= metadataFiles.length) return;

    try {
      final file = File(metadataFiles[index]);
      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      currentIndex.value = index;
      currentData.value = CaptchaDataV2.fromJson(json);
      resetTracking();
    } catch (e) {
      debugPrint('加载验证码失败: $e');
      Get.snackbar('错误', '加载验证码失败: $e');
    }
  }

  /// 重置轨迹追踪
  void resetTracking() {
    moveLength.value = 0;
    timerTracks.clear();
    eventTracks.clear();
    isDragging.value = false;
    _dragStartTime = null;
  }

  /// 开始拖动
  void handleDragStart(double startX, double startY) {
    if (currentData.value == null) return;

    isDragging.value = true;
    _startX = startX;
    _startY = startY;
    _initialMoveLength = moveLength.value;
    _dragStartTime = DateTime.now();

    // 清空轨迹
    timerTracks.clear();
    eventTracks.clear();

    // 记录起点
    final startPoint = RawTrackPoint(
      x: 0,
      y: 0,
      timestamp: 0,
      interval: 0,
    );
    eventTracks.add(startPoint);
  }

  /// 拖动更新（无防抖，记录所有事件）
  void handleDragUpdate(double currentX, double currentY) {
    if (!isDragging.value || _dragStartTime == null) return;

    // 计算新位置
    final deltaX = currentX - _startX;
    final newPosition = (_initialMoveLength + deltaX).clamp(0.0, maxMove);
    moveLength.value = newPosition;

    // 获取当前时间
    final now = DateTime.now();
    final elapsed = now.difference(_dragStartTime!).inMilliseconds;
    final offsetY = (currentY - _startY).round();

    // 记录到eventTracks（无防抖，记录所有onPanUpdate事件）
    final eventInterval = eventTracks.isEmpty ? 0 : elapsed - eventTracks.last.timestamp;
    eventTracks.add(RawTrackPoint(
      x: newPosition.round(),
      y: offsetY,
      timestamp: elapsed,
      interval: eventInterval,
    ));
  }

  /// 拖动结束
  void handleDragEnd(double endX, double endY) {
    if (!isDragging.value) return;

    isDragging.value = false;

    // 从eventTracks重采样生成timerTracks
    _resampleTimerTracks();

    // 输出统计
    debugPrint('=== V2采集完成 ===');
    debugPrint('原始事件点: ${eventTracks.length}');
    debugPrint('重采样点: ${timerTracks.length}');
    debugPrint('总时长: ${eventTracks.isNotEmpty ? eventTracks.last.timestamp : 0}ms');

    if (eventTracks.length > 1) {
      final intervals = <int>[];
      for (int i = 1; i < eventTracks.length; i++) {
        intervals.add(eventTracks[i].interval);
      }
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      final minInterval = intervals.reduce((a, b) => a < b ? a : b);
      final maxInterval = intervals.reduce((a, b) => a > b ? a : b);
      debugPrint('事件间隔 - 平均: ${avgInterval.toStringAsFixed(1)}ms, 最小: ${minInterval}ms, 最大: ${maxInterval}ms');
    }

    if (timerTracks.length > 1) {
      final avgInterval = (timerTracks.last.timestamp - timerTracks.first.timestamp) / (timerTracks.length - 1);
      debugPrint('重采样后间隔 - 理论: ${timerInterval}ms, 实际平均: ${avgInterval.toStringAsFixed(1)}ms');
    }
  }

  /// 从eventTracks重采样生成均匀的timerTracks（线性插值）
  void _resampleTimerTracks() {
    timerTracks.clear();

    if (eventTracks.length < 2) {
      // 事件点太少，无法插值
      timerTracks.addAll(eventTracks);
      return;
    }

    final totalTime = eventTracks.last.timestamp;
    if (totalTime <= 0) return;

    // 生成均匀的时间点：0, timerInterval, 2*timerInterval, ...
    for (int t = 0; t <= totalTime; t += timerInterval) {
      final point = _interpolatePoint(t);
      if (point != null) {
        timerTracks.add(point);
      }
    }

    // 确保最后一个点也被包含
    if (timerTracks.isEmpty || timerTracks.last.timestamp < totalTime) {
      final lastPoint = eventTracks.last;
      timerTracks.add(lastPoint);
    }

    debugPrint('重采样完成: ${eventTracks.length}个事件点 -> ${timerTracks.length}个均匀点');
  }

  /// 在指定时间点从eventTracks进行线性插值
  RawTrackPoint? _interpolatePoint(int targetTime) {
    if (eventTracks.isEmpty) return null;

    // 找到targetTime前后的两个点
    RawTrackPoint? before;
    RawTrackPoint? after;

    for (int i = 0; i < eventTracks.length; i++) {
      final point = eventTracks[i];
      if (point.timestamp <= targetTime) {
        before = point;
      }
      if (point.timestamp >= targetTime && after == null) {
        after = point;
        break;
      }
    }

    // 边界情况
    if (before == null) return eventTracks.first;
    if (after == null) return eventTracks.last;
    if (before.timestamp == after.timestamp) return before;

    // 线性插值
    final ratio = (targetTime - before.timestamp) / (after.timestamp - before.timestamp);
    final x = (before.x + (after.x - before.x) * ratio).round();
    final y = (before.y + (after.y - before.y) * ratio).round();

    final interval = timerTracks.isEmpty ? targetTime : targetTime - timerTracks.last.timestamp;

    return RawTrackPoint(
      x: x,
      y: y,
      timestamp: targetTime,
      interval: interval,
    );
  }

  /// 保存标注
  Future<void> saveAnnotation() async {
    if (currentData.value == null || timerTracks.isEmpty) {
      Get.snackbar('错误', '没有可保存的轨迹数据');
      return;
    }

    try {
      debugPrint('=== 保存前检查 ===');
      debugPrint('timerTracks数量: ${timerTracks.length}');
      debugPrint('eventTracks数量: ${eventTracks.length}');

      final metadata = _calculateMetadata();

      final updatedData = CaptchaDataV2(
        id: currentData.value!.id,
        timestamp: currentData.value!.timestamp,
        bigImage: currentData.value!.bigImage,
        smallImage: currentData.value!.smallImage,
        yHeight: currentData.value!.yHeight,
        canvasLength: currentData.value!.canvasLength,
        targetDistance: moveLength.value.round(),
        timerTracks: timerTracks.toList(),
        eventTracks: eventTracks.toList(),
        metadata: metadata,
        rawJson: currentData.value!.rawJson,
      );

      final jsonMap = updatedData.toJson();
      debugPrint('JSON包含timerTracks: ${jsonMap.containsKey("timerTracks")}');
      debugPrint('JSON包含eventTracks: ${jsonMap.containsKey("eventTracks")}');
      debugPrint('JSON eventTracks长度: ${(jsonMap["eventTracks"] as List?)?.length}');

      final file = File(metadataFiles[currentIndex.value]);
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      await file.writeAsString(jsonString);

      debugPrint('JSON文件已保存到: ${file.path}');
      debugPrint('JSON包含"eventTracks"字符串: ${jsonString.contains("eventTracks")}');

      Get.snackbar('成功', '标注已保存！');

      // 加载下一个
      if (currentIndex.value < metadataFiles.length - 1) {
        await loadCaptcha(currentIndex.value + 1);
      } else {
        Get.snackbar('完成', '所有验证码已标注完成！');
      }
    } catch (e) {
      debugPrint('保存标注失败: $e');
      Get.snackbar('错误', '保存标注失败: $e');
    }
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

    final totalTime = timerTracks.last.timestamp;

    double avgEventInterval = 0.0;
    if (eventTracks.length > 1) {
      final totalInterval = eventTracks.skip(1).fold<int>(
        0, (sum, p) => sum + p.interval,
      );
      avgEventInterval = totalInterval / (eventTracks.length - 1);
    }

    // 避免除以0产生Infinity
    final samplingRate = totalTime > 0
        ? timerTracks.length / (totalTime / 1000.0)
        : 0.0;

    return TrajectoryMetadata(
      totalTime: totalTime,
      timerPointCount: timerTracks.length,
      eventPointCount: eventTracks.length,
      avgEventInterval: avgEventInterval,
      samplingRate: samplingRate,
    );
  }

  /// 上一个验证码
  void previousCaptcha() {
    if (currentIndex.value > 0) {
      loadCaptcha(currentIndex.value - 1);
    }
  }

  /// 下一个验证码
  void nextCaptcha() {
    if (currentIndex.value < metadataFiles.length - 1) {
      loadCaptcha(currentIndex.value + 1);
    }
  }

  /// 跳过当前验证码
  void skipCaptcha() {
    nextCaptcha();
  }
}
