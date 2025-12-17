import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import '../models/captcha_data.dart';

class CaptchaController extends GetxController {
  final String datasetPath;

  CaptchaController({required this.datasetPath});

  // Observable state
  final metadataFiles = <String>[].obs;
  final currentIndex = 0.obs;
  final Rx<CaptchaData?> currentData = Rx<CaptchaData?>(null);

  final moveLength = 0.0.obs;
  final tracks = <TrackPoint>[].obs;
  final isDragging = false.obs;

  DateTime? _lastRecordTime;
  TrackPoint? _lastTrack;

  // Record initial position for calculating offsets
  double _startX = 0;
  double _startY = 0;
  double _initialMoveLength = 0; // Initial slider position when drag starts

  // Constants
  static const double canvasWidth = 280;
  static const double sliderBtnWidth = 40;
  static const double maxMove = canvasWidth - sliderBtnWidth;
  static const int minTimeInterval = 20;
  static const double minDistance = 2;

  @override
  void onInit() {
    super.onInit();
    loadMetadataFiles();
  }

  Future<void> loadMetadataFiles() async {
    try {
      final metadataDir = Directory('$datasetPath/metadata');
      if (!await metadataDir.exists()) {
        Get.snackbar(
          'Error',
          'Metadata directory not found',
          snackPosition: SnackPosition.BOTTOM,
        );
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
      Get.snackbar(
        'Error',
        'Failed to load metadata files: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> loadCaptcha(int index) async {
    if (index < 0 || index >= metadataFiles.length) return;

    try {
      final file = File(metadataFiles[index]);
      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      currentIndex.value = index;
      currentData.value = CaptchaData.fromJson(json);

      // Load existing annotation if available
      if (currentData.value?.targetDistance != null &&
          currentData.value?.tracks != null &&
          currentData.value!.tracks!.isNotEmpty) {
        // Restore the annotated data
        moveLength.value = currentData.value!.targetDistance!.toDouble();
        tracks.value = List<TrackPoint>.from(currentData.value!.tracks!);
        isDragging.value = false;
        _lastRecordTime = null;
        _lastTrack = null;
      } else {
        // No annotation, reset to clean state
        resetTracking();
      }
    } catch (e) {
      print(e);
      Get.snackbar(
        'Error',
        'Failed to load captcha: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void resetTracking() {
    moveLength.value = 0;
    tracks.clear();
    isDragging.value = false;
    _lastRecordTime = null;
    _lastTrack = null;
  }

  void handleDragStart(double startX, double startY) {
    if (currentData.value == null) return;

    isDragging.value = true;
    _startX = startX;
    _startY = startY;
    _initialMoveLength = moveLength.value; // Remember current position
    _lastRecordTime = DateTime.now();
    tracks.value = [TrackPoint(a: 0, b: 0, c: 0)];
    _lastTrack = null;
  }

  void handleDragUpdate(double currentX, double currentY) {
    if (!isDragging.value) return;

    final now = DateTime.now();
    // Calculate drag delta from start position
    final deltaX = currentX - _startX;
    // New position = initial position + drag delta
    final newPosition = (_initialMoveLength + deltaX).clamp(0.0, maxMove);
    moveLength.value = newPosition;

    final timeDiff = now.difference(_lastRecordTime!).inMilliseconds;
    if (timeDiff < minTimeInterval) return;

    final offsetY = (currentY - _startY).round();

    final newTrack = TrackPoint(
      a: newPosition.round(),
      b: offsetY,
      c: timeDiff,
    );

    // Distance filtering
    if (_lastTrack != null) {
      final dx = newTrack.a - _lastTrack!.a;
      final dy = newTrack.b - _lastTrack!.b;
      final distance = (dx * dx + dy * dy);
      if (distance < minDistance * minDistance) return;
    }

    tracks.add(newTrack);
    _lastTrack = newTrack;
    _lastRecordTime = now;
  }

  void handleDragEnd(double endX, double endY) {
    if (!isDragging.value) return;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastRecordTime!).inMilliseconds;
    final offsetY = (endY - _startY).round();

    final finalTrack = TrackPoint(
      a: moveLength.value.round(),
      b: offsetY,
      c: timeDiff,
    );

    tracks.add(finalTrack);
    isDragging.value = false;
  }

  Future<void> saveAnnotation() async {
    if (currentData.value == null || tracks.isEmpty) {
      print( 'No tracks to save');
      Get.snackbar(
        'Error',
        'No tracks to save',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final updatedData = CaptchaData(
        id: currentData.value!.id,
        timestamp: currentData.value!.timestamp,
        bigImage: currentData.value!.bigImage,
        smallImage: currentData.value!.smallImage,
        yHeight: currentData.value!.yHeight,
        canvasLength: currentData.value!.canvasLength,
        targetDistance: moveLength.value.round(),
        tracks: tracks.toList(),
        rawJson: currentData.value!.rawJson,
      );

      final file = File(metadataFiles[currentIndex.value]);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(updatedData.toJson()),
      );

      Get.snackbar(
        'Success',
        'Annotation saved successfully!',
        snackPosition: SnackPosition.BOTTOM,
      );

      // Load next captcha
      if (currentIndex.value < metadataFiles.length - 1) {
        await loadCaptcha(currentIndex.value + 1);
      }
    } catch (e) {
      print(e);
      Get.snackbar(
        'Error',
        'Failed to save annotation: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void previousCaptcha() {
    if (currentIndex.value > 0) {
      loadCaptcha(currentIndex.value - 1);
    }
  }

  void nextCaptcha() {
    if (currentIndex.value < metadataFiles.length - 1) {
      loadCaptcha(currentIndex.value + 1);
    }
  }

  String getBigImagePath() {
    return '$datasetPath/images/${currentData.value?.bigImage.file ?? ''}';
  }

  String getSmallImagePath() {
    return '$datasetPath/images/${currentData.value?.smallImage.file ?? ''}';
  }

  String get statusText {
    if (isDragging.value) {
      return '✋ Recording trajectory...';
    } else if (tracks.isNotEmpty) {
      final isLoadedAnnotation = isAnnotated &&
          currentData.value?.targetDistance == moveLength.value.round();
      if (isLoadedAnnotation) {
        return '📋 Loaded annotation - Move distance: ${moveLength.value.round()}px (Click Reset to re-annotate)';
      } else {
        return '✅ Complete! Move distance: ${moveLength.value.round()}px';
      }
    } else {
      return '👉 Please drag the slider to complete the puzzle';
    }
  }

  String get currentFileName {
    if (currentIndex.value < 0 || currentIndex.value >= metadataFiles.length) {
      return '';
    }
    final filePath = metadataFiles[currentIndex.value];
    return filePath.split('/').last;
  }

  bool get isAnnotated {
    final data = currentData.value;
    if (data == null) return false;
    return data.targetDistance != null &&
           data.tracks != null &&
           data.tracks!.isNotEmpty;
  }

  List<Map<String, double>> get positionData {
    if (tracks.isEmpty) return [];

    double cumulativeTime = 0;
    final data = <Map<String, double>>[];

    for (var track in tracks) {
      cumulativeTime += track.c;
      data.add({'time': cumulativeTime, 'value': track.a.toDouble()});
    }

    return data;
  }

  List<Map<String, double>> get velocityData {
    if (tracks.isEmpty) return [];

    final posData = positionData;
    if (posData.length < 2) return [];

    final data = <Map<String, double>>[];
    data.add({'time': 0.0, 'value': 0.0}); // 初始速度为0

    for (int i = 1; i < posData.length; i++) {
      final dt = posData[i]['time']! - posData[i - 1]['time']!;
      final dx = posData[i]['value']! - posData[i - 1]['value']!;
      final v = dt > 0 ? (dx / dt) * 1000 : 0.0; // px/s
      data.add({'time': posData[i]['time']!, 'value': v});
    }

    return data;
  }

  List<Map<String, double>> get accelerationData {
    if (tracks.isEmpty) return [];

    final velData = velocityData;
    if (velData.length < 2) return [];

    final data = <Map<String, double>>[];
    data.add({'time': 0.0, 'value': 0.0}); // 初始加速度为0

    for (int i = 1; i < velData.length; i++) {
      final dt = velData[i]['time']! - velData[i - 1]['time']!;
      final dv = velData[i]['value']! - velData[i - 1]['value']!;
      final a = dt > 0 ? (dv / (dt / 1000)) : 0.0; // px/s²
      data.add({'time': velData[i]['time']!, 'value': a});
    }

    return data;
  }

  String get outputJson {
    if (tracks.isEmpty) return '';

    final output = {
      'canvasLength': CaptchaController.canvasWidth.toInt(),
      'moveLength': moveLength.value.round(),
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };

    return jsonEncode(output);
  }
}
