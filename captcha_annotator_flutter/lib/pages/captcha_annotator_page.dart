import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/captcha_controller.dart';
import '../models/captcha_data.dart';

class CaptchaAnnotatorPage extends GetView<CaptchaController> {
  const CaptchaAnnotatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captcha Annotator'),
        actions: [
          Obx(() {
            if (controller.currentData.value == null) return const SizedBox();
            return Row(
              children: [
                IconButton(
                  onPressed: controller.currentIndex.value > 0
                      ? controller.previousCaptcha
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${controller.currentIndex.value + 1} / ${controller.metadataFiles.length}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: controller.currentIndex.value < controller.metadataFiles.length - 1
                      ? controller.nextCaptcha
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Next',
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: controller.resetTracking,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset',
                ),
                const SizedBox(width: 8),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.currentData.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildAnnotatorBody();
      }),
      floatingActionButton: Obx(() {
        if (controller.tracks.isEmpty) return const SizedBox();
        return FloatingActionButton.extended(
          onPressed: controller.saveAnnotation,
          label: const Text('Save & Next'),
          icon: const Icon(Icons.save),
        );
      }),
    );
  }

  Widget _buildAnnotatorBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFileInfoCard(),
              const SizedBox(height: 20),
              _buildStatusCard(),
              const SizedBox(height: 20),
              _buildTestSection(),
              const SizedBox(height: 20),
              _buildCaptchaArea(),
              const SizedBox(height: 20),
              Obx(() {
                if (controller.tracks.isEmpty) return const SizedBox();
                return Column(
                  children: [
                    _buildCharts(),
                    const SizedBox(height: 20),
                    _buildOutputSection(),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Obx(() {
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
                      controller.currentFileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${controller.currentData.value?.id ?? ''}',
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
                  color: controller.isAnnotated
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: controller.isAnnotated
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      controller.isAnnotated ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: controller.isAnnotated
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      controller.isAnnotated ? 'Annotated' : 'Not Annotated',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: controller.isAnnotated
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

  Widget _buildStatusCard() {
    return Obx(() {
      Color statusColor;
      if (controller.isDragging.value) {
        statusColor = Colors.blue.shade100;
      } else if (controller.tracks.isNotEmpty) {
        statusColor = Colors.green.shade100;
      } else {
        statusColor = Colors.yellow.shade100;
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          controller.statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    });
  }

  Widget _buildTestSection() {
    final jsonController = TextEditingController();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test JSON Input/Output',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: jsonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Paste JSON here to test',
                border: OutlineInputBorder(),
                hintText: '{"smallImage":"...","bigImage":"..."}',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final json = jsonController.text.trim();
                    if (json.isEmpty) {
                      Get.snackbar(
                        'Error',
                        'Please enter JSON data',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                      return;
                    }

                    try {
                      final data = jsonDecode(json);
                      // Test parse
                      Get.snackbar(
                        'Success',
                        'JSON is valid!',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        'Invalid JSON: $e',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Validate'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    jsonController.clear();
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
          ],
        ),
      ),
    );
  }

  Widget _buildCaptchaImages() {
    return Obx(() {
      final data = controller.currentData.value!;
      // 根据实际图片高度计算缩放比例和 Y 偏移
      const displayHeight = 155.0;
      final originalHeight = data.bigImage.height.toDouble(); // 使用实际图片高度
      final scale = displayHeight / originalHeight;
      final yOffset = (data.yHeight ?? 0) * scale;

      return Container(
        width: CaptchaController.canvasWidth,
        height: displayHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Background image
            Image.file(
              File(controller.getBigImagePath()),
              width: CaptchaController.canvasWidth,
              height: displayHeight,
              fit: BoxFit.cover,
            ),
            // Slider piece - 使用 yHeight 按实际比例定位
            Positioned(
              left: controller.moveLength.value,
              top: yOffset,
              child: Image.file(
                File(controller.getSmallImagePath()),
                height: displayHeight,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: CaptchaController.canvasWidth,
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
                      width: CaptchaController.sliderBtnWidth,
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
      },
    );
  }

  Widget _buildCharts() {
    return Column(
      children: [
        _buildChart(
          title: 'Position (位移)',
          data: controller.positionData,
          color: Colors.blue,
          yLabel: 'px',
        ),
        const SizedBox(height: 20),
        _buildChart(
          title: 'Velocity (速度)',
          data: controller.velocityData,
          color: Colors.green,
          yLabel: 'px/s',
        ),
        const SizedBox(height: 20),
        _buildChart(
          title: 'Acceleration (加速度)',
          data: controller.accelerationData,
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
                  'Output JSON',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: controller.outputJson));
                    Get.snackbar(
                      'Success',
                      'JSON copied to clipboard!',
                      snackPosition: SnackPosition.BOTTOM,
                    );
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
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Obx(() {
                  return SelectableText(
                    controller.outputJson,
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
}
