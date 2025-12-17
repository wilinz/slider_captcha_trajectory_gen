import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/captcha_controller_v2.dart';
import '../models/captcha_data_v2.dart';

/// V2版本采集器页面 - 双序列采集
class CaptchaAnnotatorV2Page extends StatelessWidget {
  const CaptchaAnnotatorV2Page({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CaptchaControllerV2());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captcha Annotator V2 - 双序列采集'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSamplingConfig(controller),
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
                      _buildDualSequenceView(controller),
                      const SizedBox(height: 20),
                      _buildActionButtons(controller),
                      const SizedBox(height: 20),
                      _buildOutputSection(controller),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 采样配置卡片
  Widget _buildSamplingConfig(CaptchaControllerV2 controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(
                  '采样配置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildConfigItem(
                    '定时器间隔',
                    '${CaptchaControllerV2.timerInterval}ms',
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildConfigItem(
                    '采样率',
                    '${1000 ~/ CaptchaControllerV2.timerInterval}Hz',
                    Icons.speed,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildConfigItem(
                    '画布宽度',
                    '${CaptchaControllerV2.canvasWidth.toInt()}px',
                    Icons.straighten,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard(CaptchaControllerV2 controller) {
    return Obx(() {
      Color statusColor;
      String statusText;
      IconData statusIcon;

      if (controller.isDragging.value) {
        statusColor = Colors.blue;
        statusText = '正在记录... (定时器: ${controller.timerTracks.length}点, 事件: ${controller.eventTracks.length}点)';
        statusIcon = Icons.fiber_manual_record;
      } else if (controller.timerTracks.isNotEmpty) {
        statusColor = Colors.green;
        statusText = '记录完成 - 定时器: ${controller.timerTracks.length}点, 事件: ${controller.eventTracks.length}点';
        statusIcon = Icons.check_circle;
      } else {
        statusColor = Colors.orange;
        statusText = '拖动滑块开始采集';
        statusIcon = Icons.touch_app;
      }

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// 滑块区域
  Widget _buildCaptchaArea(CaptchaControllerV2 controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '拖动滑块进行测试',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 20),
            // 滑块轨道
            Container(
              height: 50,
              width: CaptchaControllerV2.canvasWidth,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Stack(
                children: [
                  // 滑块
                  Obx(() {
                    return Positioned(
                      left: controller.moveLength.value,
                      child: GestureDetector(
                        onPanStart: (details) {
                          controller.handleDragStart(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          );
                        },
                        onPanUpdate: (details) {
                          controller.handleDragUpdate(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          );
                        },
                        onPanEnd: (details) {
                          controller.handleDragEnd(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          );
                        },
                        child: Container(
                          width: CaptchaControllerV2.sliderBtnWidth,
                          height: 50,
                          decoration: BoxDecoration(
                            color: controller.isDragging.value
                                ? Colors.blue
                                : Colors.indigo,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              return Text(
                '当前位置: ${controller.moveLength.value.toInt()}px',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 统计信息卡片
  Widget _buildStatisticsCard(CaptchaControllerV2 controller) {
    return Obx(() {
      if (controller.timerTracks.isEmpty) return const SizedBox();

      final metadata = controller.exportData(
        id: 'temp',
        canvasLength: CaptchaControllerV2.canvasWidth.toInt(),
        targetDistance: controller.moveLength.value.toInt(),
      ).metadata;

      if (metadata == null) return const SizedBox();

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '采集统计',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '总时长',
                      '${metadata.totalTime}ms',
                      Icons.timer,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '定时器点数',
                      '${metadata.timerPointCount}',
                      Icons.grain,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '事件点数',
                      '${metadata.eventPointCount}',
                      Icons.touch_app,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '平均事件间隔',
                      '${metadata.avgEventInterval.toStringAsFixed(1)}ms',
                      Icons.access_time,
                      Colors.purple,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '实际采样率',
                      '${metadata.samplingRate.toStringAsFixed(0)}Hz',
                      Icons.speed,
                      Colors.teal,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '数据密度',
                      '${(metadata.timerPointCount / metadata.eventPointCount).toStringAsFixed(1)}x',
                      Icons.data_usage,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 双序列对比视图
  Widget _buildDualSequenceView(CaptchaControllerV2 controller) {
    return Obx(() {
      if (controller.timerTracks.isEmpty) return const SizedBox();

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '双序列对比',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      // 定时器序列（连续曲线）
                      LineChartBarData(
                        spots: controller.timerTracks
                            .map((p) => FlSpot(
                                  p.timestamp.toDouble(),
                                  p.x.toDouble(),
                                ))
                            .toList(),
                        isCurved: false,
                        color: Colors.blue,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withOpacity(0.1),
                        ),
                      ),
                      // 事件序列（离散点）
                      LineChartBarData(
                        spots: controller.eventTracks
                            .map((p) => FlSpot(
                                  p.timestamp.toDouble(),
                                  p.x.toDouble(),
                                ))
                            .toList(),
                        isCurved: false,
                        color: Colors.red,
                        barWidth: 0,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.red,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegend('定时器采样', Colors.blue),
                  const SizedBox(width: 20),
                  _buildLegend('事件触发', Colors.red),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(CaptchaControllerV2 controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            controller.moveLength.value = 0;
            controller.timerTracks.clear();
            controller.eventTracks.clear();
            Get.snackbar(
              '已重置',
              '轨迹数据已清空',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
            );
          },
          icon: const Icon(Icons.refresh),
          label: const Text('重置'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            final data = controller.exportData(
              id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
              canvasLength: CaptchaControllerV2.canvasWidth.toInt(),
              targetDistance: controller.moveLength.value.toInt(),
            );
            final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
            Clipboard.setData(ClipboardData(text: jsonStr));
            Get.snackbar(
              '已保存',
              'JSON数据已复制到剪贴板',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('保存到剪贴板'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  /// 输出JSON
  Widget _buildOutputSection(CaptchaControllerV2 controller) {
    return Obx(() {
      if (controller.timerTracks.isEmpty) return const SizedBox();

      final data = controller.exportData(
        id: 'sample_${DateTime.now().millisecondsSinceEpoch}',
        canvasLength: CaptchaControllerV2.canvasWidth.toInt(),
        targetDistance: controller.moveLength.value.toInt(),
      );

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.code, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'JSON 输出',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      Get.snackbar('成功', '已复制到剪贴板');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('复制'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('双序列采集说明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoItem(
                '定时器采样',
                '每${CaptchaControllerV2.timerInterval}ms记录一次真实位置，获得完整的运动曲线',
                Icons.timer,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                '事件触发',
                'onPanUpdate触发时记录，反映系统的真实采样特性',
                Icons.touch_app,
                Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                '优势：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('✅ 真实数据，无插值\n✅ 完整运动曲线\n✅ 准确的速度/加速度'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String desc, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
