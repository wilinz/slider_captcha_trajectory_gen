import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/captcha_annotator_controller_v2.dart';
import '../models/captcha_data_v2.dart';

class CaptchaDatasetAnnotatorV2Page extends StatelessWidget {
  final String datasetPath;

  const CaptchaDatasetAnnotatorV2Page({
    super.key,
    required this.datasetPath,
  });

  @override
  Widget build(BuildContext context) {
    // 使用tag避免多个实例冲突
    final controller = Get.put(
      CaptchaAnnotatorControllerV2(datasetPath: datasetPath),
      tag: datasetPath,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('V2 Dataset Annotator - Real Sampling'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          Obx(() {
            if (controller.currentData.value == null) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '${controller.currentIndex.value + 1} / ${controller.metadataFiles.length}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.currentData.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildAnnotatorBody(controller);
      }),
      floatingActionButton: Obx(() {
        if (controller.timerTracks.isEmpty) return const SizedBox();
        return FloatingActionButton.extended(
          onPressed: controller.saveAnnotation,
          label: const Text('Save & Next'),
          icon: const Icon(Icons.save),
          backgroundColor: Colors.green,
        );
      }),
    );
  }

  Widget _buildAnnotatorBody(CaptchaAnnotatorControllerV2 controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFileInfoCard(controller),
              const SizedBox(height: 20),
              _buildStatusCard(controller),
              const SizedBox(height: 20),
              _buildCaptchaArea(controller),
              const SizedBox(height: 20),
              Obx(() {
                if (controller.timerTracks.isEmpty) return const SizedBox();
                return Column(
                  children: [
                    _buildStatisticsCard(controller),
                    const SizedBox(height: 20),
                    _buildDualSequenceChart(controller),
                    const SizedBox(height: 20),
                    _buildOutputSection(controller),
                  ],
                );
              }),
              const SizedBox(height: 20),
              _buildNavigationButtons(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfoCard(CaptchaAnnotatorControllerV2 controller) {
    return Obx(() {
      final data = controller.currentData.value!;
      final isAnnotated = data.timerTracks != null && data.timerTracks!.isNotEmpty;

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID: ${data.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Canvas: ${data.canvasLength}px',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAnnotated
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAnnotated
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAnnotated ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: isAnnotated
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAnnotated ? 'V2 Annotated' : 'Not Annotated',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAnnotated
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatusCard(CaptchaAnnotatorControllerV2 controller) {
    return Obx(() {
      Color statusColor;
      String statusText;

      if (controller.isDragging.value) {
        statusColor = Colors.blue.shade100;
        statusText = '⏺ Recording... (5ms timer sampling)';
      } else if (controller.timerTracks.isNotEmpty) {
        statusColor = Colors.green.shade100;
        statusText = '✓ Drag completed! Click "Save & Next" to continue';
      } else {
        statusColor = Colors.yellow.shade100;
        statusText = '👆 Drag the slider to annotate';
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
    });
  }

  Widget _buildCaptchaArea(CaptchaAnnotatorControllerV2 controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCaptchaImages(controller),
            const SizedBox(height: 20),
            _buildSlider(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptchaImages(CaptchaAnnotatorControllerV2 controller) {
    return Obx(() {
      final data = controller.currentData.value!;
      const displayHeight = 155.0;
      final originalHeight = data.bigImage!.height.toDouble();
      final scale = displayHeight / originalHeight;
      final yOffset = (data.yHeight ?? 0) * scale;

      final bigImagePath = '${controller.datasetPath}/images/${data.bigImage!.file}';
      final smallImagePath = '${controller.datasetPath}/images/${data.smallImage!.file}';

      return Container(
        width: CaptchaAnnotatorControllerV2.canvasWidth,
        height: displayHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Background image
            Image.file(
              File(bigImagePath),
              width: CaptchaAnnotatorControllerV2.canvasWidth,
              height: displayHeight,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: Center(child: Text('Big image error: $error')),
                );
              },
            ),
            // Slider piece
            Positioned(
              left: controller.moveLength.value,
              top: yOffset,
              child: Image.file(
                File(smallImagePath),
                height: displayHeight,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 50,
                    height: displayHeight,
                    color: Colors.red[300],
                    child: const Center(child: Icon(Icons.error)),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSlider(CaptchaAnnotatorControllerV2 controller) {
    return SizedBox(
      width: CaptchaAnnotatorControllerV2.canvasWidth,
      height: 40,
      child: Obx(() {
        return Stack(
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
                width: controller.moveLength.value + 20,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
            // Slider button
            Positioned(
              left: controller.moveLength.value,
              top: 0,
              child: GestureDetector(
                onPanStart: (details) {
                  final startX = details.globalPosition.dx;
                  final startY = details.globalPosition.dy;
                  controller.handleDragStart(startX, startY);
                },
                onPanUpdate: (details) {
                  final currentX = details.globalPosition.dx;
                  final currentY = details.globalPosition.dy;
                  controller.handleDragUpdate(currentX, currentY);
                },
                onPanEnd: (details) {
                  final endX = details.globalPosition.dx;
                  final endY = details.globalPosition.dy;
                  controller.handleDragEnd(endX, endY);
                },
                child: Container(
                  width: CaptchaAnnotatorControllerV2.sliderBtnWidth,
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
        );
      }),
    );
  }

  Widget _buildStatisticsCard(CaptchaAnnotatorControllerV2 controller) {
    return Obx(() {
      if (controller.timerTracks.isEmpty) return const SizedBox();

      final timerCount = controller.timerTracks.length;
      final eventCount = controller.eventTracks.length;
      final totalTime = controller.timerTracks.last.timestamp;

      double avgEventInterval = 0;
      if (eventCount > 1) {
        final totalInterval = controller.eventTracks.skip(1).fold<int>(
          0, (sum, p) => sum + p.interval,
        );
        avgEventInterval = totalInterval / (eventCount - 1);
      }

      final samplingRate = timerCount / (totalTime / 1000.0);

      return Card(
        color: Colors.blue.shade50,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Sampling Statistics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Time', '${totalTime}ms'),
                  _buildStatItem('Timer Points', '$timerCount'),
                  _buildStatItem('Event Points', '$eventCount'),
                  _buildStatItem('Avg Interval', '${avgEventInterval.toStringAsFixed(1)}ms'),
                  _buildStatItem('Sample Rate', '${samplingRate.toStringAsFixed(1)}Hz'),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDualSequenceChart(CaptchaAnnotatorControllerV2 controller) {
    return Obx(() {
      if (controller.timerTracks.isEmpty) return const SizedBox();

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📈 Dual Sequence Trajectory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Blue line: Timer sampling (5ms) | Red dots: Event triggers',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        axisNameWidget: Text('Position (px)', style: TextStyle(fontSize: 12)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                        axisNameWidget: Text('Time (ms)', style: TextStyle(fontSize: 12)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      // Timer sequence (blue line)
                      LineChartBarData(
                        spots: controller.timerTracks.map((p) {
                          return FlSpot(p.timestamp.toDouble(), p.x.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.1),
                        ),
                      ),
                      // Event sequence (red dots)
                      LineChartBarData(
                        spots: controller.eventTracks.map((p) {
                          return FlSpot(p.timestamp.toDouble(), p.x.toDouble());
                        }).toList(),
                        isCurved: false,
                        color: Colors.red,
                        barWidth: 0,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildOutputSection(CaptchaAnnotatorControllerV2 controller) {
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
                  'Output JSON (V2 Format)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final data = controller.currentData.value!;
                    TrajectoryMetadata? metadata;
                    if (controller.timerTracks.isNotEmpty) {
                      final totalTime = controller.timerTracks.last.timestamp;
                      metadata = TrajectoryMetadata(
                        totalTime: totalTime,
                        timerPointCount: controller.timerTracks.length,
                        eventPointCount: controller.eventTracks.length,
                        avgEventInterval: controller.eventTracks.length > 1
                            ? controller.eventTracks.skip(1).fold<int>(0, (sum, p) => sum + p.interval) / (controller.eventTracks.length - 1)
                            : 0.0,
                        samplingRate: totalTime > 0
                            ? controller.timerTracks.length / (totalTime / 1000.0)
                            : 0.0,
                      );
                    }

                    final outputData = CaptchaDataV2(
                      id: data.id,
                      timestamp: data.timestamp,
                      bigImage: data.bigImage,
                      smallImage: data.smallImage,
                      yHeight: data.yHeight,
                      canvasLength: data.canvasLength,
                      targetDistance: controller.moveLength.value.round(),
                      timerTracks: controller.timerTracks.toList(),
                      eventTracks: controller.eventTracks.toList(),
                      metadata: metadata,
                      rawJson: data.rawJson,
                    );

                    final jsonStr = const JsonEncoder.withIndent('  ').convert(outputData.toJson());
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    Get.snackbar('Success', 'JSON copied to clipboard!');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
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
              constraints: const BoxConstraints(maxHeight: 400), // 增加到400px
              child: SingleChildScrollView(
                child: Obx(() {
                  if (controller.timerTracks.isEmpty) {
                    return const SelectableText(
                      '// Drag the slider to generate JSON output',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    );
                  }

                  final data = controller.currentData.value!;
                  final totalTime = controller.timerTracks.last.timestamp;
                  final metadata = TrajectoryMetadata(
                    totalTime: totalTime,
                    timerPointCount: controller.timerTracks.length,
                    eventPointCount: controller.eventTracks.length,
                    avgEventInterval: controller.eventTracks.length > 1
                        ? controller.eventTracks.skip(1).fold<int>(0, (sum, p) => sum + p.interval) / (controller.eventTracks.length - 1)
                        : 0.0,
                    samplingRate: totalTime > 0
                        ? controller.timerTracks.length / (totalTime / 1000.0)
                        : 0.0,
                  );

                  final outputData = CaptchaDataV2(
                    id: data.id,
                    timestamp: data.timestamp,
                    bigImage: data.bigImage,
                    smallImage: data.smallImage,
                    yHeight: data.yHeight,
                    canvasLength: data.canvasLength,
                    targetDistance: controller.moveLength.value.round(),
                    timerTracks: controller.timerTracks.toList(),
                    eventTracks: controller.eventTracks.toList(),
                    metadata: metadata,
                    rawJson: data.rawJson,
                  );

                  final jsonStr = const JsonEncoder.withIndent('  ').convert(outputData.toJson());
                  return SelectableText(
                    jsonStr,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(CaptchaAnnotatorControllerV2 controller) {
    return Obx(() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: controller.currentIndex.value > 0
                ? controller.previousCaptcha
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
          ElevatedButton.icon(
            onPressed: controller.resetTracking,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
          ElevatedButton.icon(
            onPressed:
                controller.currentIndex.value < controller.metadataFiles.length - 1
                    ? controller.nextCaptcha
                    : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ],
      );
    });
  }
}
