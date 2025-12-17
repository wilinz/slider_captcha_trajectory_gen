import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/captcha_data.dart';

class ManualCaptchaToolPage extends StatefulWidget {
  const ManualCaptchaToolPage({super.key});

  @override
  State<ManualCaptchaToolPage> createState() => _ManualCaptchaToolPageState();
}

class _ManualCaptchaToolPageState extends State<ManualCaptchaToolPage> {
  final _jsonController = TextEditingController();

  String? _bigImageBase64;
  String? _smallImageBase64;
  int? _yHeight;

  // Cached decoded images to prevent flickering
  Uint8List? _bigImageBytes;
  Uint8List? _smallImageBytes;

  double _moveLength = 0;
  List<TrackPoint> _tracks = [];
  bool _isDragging = false;
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

  void _parseJson() {
    final json = _jsonController.text.trim();
    if (json.isEmpty) {
      Get.snackbar('Error', 'Please enter JSON data');
      return;
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;

      if (!data.containsKey('bigImage') || !data.containsKey('smallImage')) {
        Get.snackbar('Error', 'JSON must contain bigImage and smallImage');
        return;
      }

      setState(() {
        _bigImageBase64 = data['bigImage'] as String;
        _smallImageBase64 = data['smallImage'] as String;
        _yHeight = data['yHeight'] as int?;

        // Decode images once and cache
        _bigImageBytes = base64Decode(_bigImageBase64!);
        _smallImageBytes = base64Decode(_smallImageBase64!);

        _reset();
      });

      Get.snackbar('Success', 'Captcha loaded successfully!',
          duration: const Duration(seconds: 2));
    } catch (e) {
      Get.snackbar('Error', 'Invalid JSON: $e');
    }
  }

  void _reset() {
    setState(() {
      _moveLength = 0;
      _tracks = [];
      _isDragging = false;
      _lastRecordTime = null;
      _lastTrack = null;
    });
  }

  void _handleDragStart(double startX, double startY) {
    if (_bigImageBase64 == null) return;

    setState(() {
      _isDragging = true;
      _startX = startX;
      _startY = startY;
      _initialMoveLength = _moveLength; // Remember current position
      _lastRecordTime = DateTime.now();
      _tracks = [TrackPoint(a: 0, b: 0, c: 0)];
      _lastTrack = null;
    });
  }

  void _handleDragUpdate(double currentX, double currentY) {
    if (!_isDragging) return;

    final now = DateTime.now();
    // Calculate drag delta from start position
    final deltaX = currentX - _startX;
    // New position = initial position + drag delta
    final newPosition = (_initialMoveLength + deltaX).clamp(0.0, maxMove);
    final offsetY = (currentY - _startY).round(); // Y offset from start position

    setState(() {
      _moveLength = newPosition;
    });

    final timeDiff = now.difference(_lastRecordTime!).inMilliseconds;
    if (timeDiff < minTimeInterval) return;

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

    setState(() {
      _tracks.add(newTrack);
      _lastTrack = newTrack;
      _lastRecordTime = now;
    });
  }

  void _handleDragEnd(double endX, double endY) {
    if (!_isDragging) return;

    final now = DateTime.now();
    final timeDiff = now.difference(_lastRecordTime!).inMilliseconds;
    final offsetY = (endY - _startY).round();

    final finalTrack = TrackPoint(
      a: _moveLength.round(),
      b: offsetY,
      c: timeDiff,
    );

    setState(() {
      _tracks.add(finalTrack);
      _isDragging = false;
    });
  }

  String get _outputJson {
    if (_tracks.isEmpty) return '';

    final output = {
      'canvasLength': canvasWidth.toInt(),
      'moveLength': _moveLength.round(),
      'tracks': _tracks.map((t) => t.toJson()).toList(),
    };

    return jsonEncode(output);
  }

  List<Map<String, double>> get _positionData {
    if (_tracks.isEmpty) return [];

    double cumulativeTime = 0;
    final data = <Map<String, double>>[];

    for (var track in _tracks) {
      cumulativeTime += track.c;
      data.add({'time': cumulativeTime, 'value': track.a.toDouble()});
    }

    return data;
  }

  List<Map<String, double>> get _velocityData {
    if (_tracks.isEmpty) return [];

    final posData = _positionData;
    if (posData.length < 2) return [];

    final data = <Map<String, double>>[];
    data.add({'time': 0.0, 'value': 0.0});

    for (int i = 1; i < posData.length; i++) {
      final dt = posData[i]['time']! - posData[i - 1]['time']!;
      final dx = posData[i]['value']! - posData[i - 1]['value']!;
      final v = dt > 0 ? (dx / dt) * 1000 : 0.0;
      data.add({'time': posData[i]['time']!, 'value': v});
    }

    return data;
  }

  List<Map<String, double>> get _accelerationData {
    if (_tracks.isEmpty) return [];

    final velData = _velocityData;
    if (velData.length < 2) return [];

    final data = <Map<String, double>>[];
    data.add({'time': 0.0, 'value': 0.0});

    for (int i = 1; i < velData.length; i++) {
      final dt = velData[i]['time']! - velData[i - 1]['time']!;
      final dv = velData[i]['value']! - velData[i - 1]['value']!;
      final a = dt > 0 ? (dv / (dt / 1000)) : 0.0;
      data.add({'time': velData[i]['time']!, 'value': a});
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Captcha Tool'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildJsonInput(),
                const SizedBox(height: 20),
                if (_bigImageBytes != null) ...[
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildCaptchaArea(),
                  const SizedBox(height: 20),
                  if (_tracks.isNotEmpty) ...[
                    _buildCharts(),
                    const SizedBox(height: 20),
                    _buildOutputSection(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJsonInput() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'JSON Data Input',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jsonController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Paste captcha JSON here',
                border: OutlineInputBorder(),
                hintText: '{"smallImage":"...","bigImage":"...","yHeight":123}',
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _parseJson,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Parse & Load'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _jsonController.clear();
                    setState(() {
                      _bigImageBase64 = null;
                      _smallImageBase64 = null;
                      _yHeight = null;
                      _reset();
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    String statusText;

    if (_isDragging) {
      statusColor = Colors.blue.shade100;
      statusText = '✋ Recording trajectory...';
    } else if (_tracks.isNotEmpty) {
      statusColor = Colors.green.shade100;
      statusText = '✅ Complete! Move distance: ${_moveLength.round()}px';
    } else {
      statusColor = Colors.yellow.shade100;
      statusText = '👉 Please drag the slider to complete the puzzle';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCaptchaArea() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCaptchaImages(),
            const SizedBox(height: 20),
            _buildSlider(),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptchaImages() {
    if (_bigImageBytes == null || _smallImageBytes == null) {
      return const SizedBox();
    }

    // 假设原始高度为 360px（可以从图片元数据获取，这里简化处理）
    const displayHeight = 155.0;
    const originalHeight = 360.0;
    final yOffset = (_yHeight ?? 0) * (displayHeight / originalHeight);

    return Container(
      width: canvasWidth,
      height: displayHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Background image
          Image.memory(
            _bigImageBytes!,
            width: canvasWidth,
            height: displayHeight,
            fit: BoxFit.cover,
            gaplessPlayback: true, // Prevents flashing when rebuilding
          ),
          // Slider piece
          Positioned(
            left: _moveLength,
            top: yOffset,
            child: Image.memory(
              _smallImageBytes!,
              height: displayHeight,
              fit: BoxFit.cover,
              gaplessPlayback: true, // Prevents flashing when rebuilding
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: canvasWidth,
          height: 40,
          child: Stack(
            children: [
              // Background
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
              // Progress bar
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: _moveLength + 20,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade100,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
              ),
              // Slider button
              Positioned(
                left: _moveLength,
                top: 0,
                child: GestureDetector(
                  onPanStart: (details) {
                    final startX = details.globalPosition.dx;
                    final startY = details.globalPosition.dy;
                    _handleDragStart(startX, startY);
                  },
                  onPanUpdate: (details) {
                    final currentX = details.globalPosition.dx;
                    final currentY = details.globalPosition.dy;
                    _handleDragUpdate(currentX, currentY);
                  },
                  onPanEnd: (details) {
                    final endX = details.globalPosition.dx;
                    final endY = details.globalPosition.dy;
                    _handleDragEnd(endX, endY);
                  },
                  child: Container(
                    width: sliderBtnWidth,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCharts() {
    return Column(
      children: [
        _buildChart(
          title: 'Position (位移)',
          data: _positionData,
          color: Colors.blue,
          yLabel: 'px',
        ),
        const SizedBox(height: 20),
        _buildChart(
          title: 'Velocity (速度)',
          data: _velocityData,
          color: Colors.green,
          yLabel: 'px/s',
        ),
        const SizedBox(height: 20),
        _buildChart(
          title: 'Acceleration (加速度)',
          data: _accelerationData,
          color: Colors.red,
          yLabel: 'px/s²',
          showZeroLine: true,
        ),
      ],
    );
  }

  Widget _buildChart({
    required String title,
    required List<Map<String, double>> data,
    required Color color,
    required String yLabel,
    bool showZeroLine = false,
  }) {
    if (data.isEmpty) return const SizedBox();

    final spots = data.map((d) => FlSpot(d['time']!, d['value']!)).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 12)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const Text('ms', style: TextStyle(fontSize: 12)),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: title.contains('Position'),
                        color: color.withOpacity(0.2),
                      ),
                    ),
                  ],
                  extraLinesData: showZeroLine
                      ? ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 0,
                              color: Colors.grey,
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trajectory JSON Output',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _outputJson));
                    Get.snackbar('Success', 'JSON copied to clipboard!',
                        duration: const Duration(seconds: 2));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy JSON'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  _outputJson,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }
}
