# 运行V2版本采集器

## 快速开始

### 方法1：使用一键脚本（推荐）

```bash
cd captcha_annotator_flutter
./setup_and_run.sh
```

### 方法2：手动执行

#### 步骤1：生成JSON序列化代码

V2数据模型使用 `json_serializable`，需要生成 `.g.dart` 文件：

```bash
cd captcha_annotator_flutter
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 步骤2：运行应用

```bash
flutter run
```

#### 步骤3：进入V2采集器

启动应用后，点击主界面的 **"V2 双序列采集器"** 按钮即可进入V2采集页面。

## 使用方法

### 1. 拖动滑块
- 拖动滑块进行测试
- 定时器会自动每5ms记录一次位置
- onPanUpdate事件也会被记录

### 2. 查看统计
拖动结束后，会显示：
- 总时长
- 定时器采样点数（约200Hz）
- 事件触发点数（约20-50Hz）
- 平均事件间隔
- 实际采样率

### 3. 查看图表
双序列对比图：
- 蓝色曲线：定时器采样（连续）
- 红色点：事件触发（离散）

### 4. 导出数据
点击"保存到剪贴板"按钮，JSON数据格式：

```json
{
  "id": "sample_1234567890",
  "timestamp": 1234567890,
  "canvasLength": 280,
  "targetDistance": 145,
  "timerTracks": [
    {"x": 0, "y": 0, "timestamp": 0, "interval": 0},
    {"x": 1, "y": 0, "timestamp": 5, "interval": 5},
    ...
  ],
  "eventTracks": [
    {"x": 0, "y": 0, "timestamp": 0, "interval": 0},
    {"x": 5, "y": 1, "timestamp": 23, "interval": 23},
    ...
  ],
  "metadata": {
    "totalTime": 1520,
    "timerPointCount": 304,
    "eventPointCount": 28,
    "avgEventInterval": 54.3,
    "samplingRate": 200.0
  }
}
```

### 5. 重置
点击"重置"按钮清空轨迹数据，开始新的采集。

## 调整采样率

如果需要调整定时器采样间隔，修改 `lib/controllers/captcha_controller_v2.dart`：

```dart
static const int timerInterval = 5;  // 改为1, 5, 或10
```

推荐值：
- **1ms**: 1000Hz，数据量大，研究级精度
- **5ms**: 200Hz，推荐，平衡精度和性能 ⭐
- **10ms**: 100Hz，低端设备

## 常见问题

### Q: 图表不显示？
A: 需要安装 `fl_chart` 包：
```bash
flutter pub add fl_chart
```

### Q: JSON序列化报错？
A: 运行 build_runner：
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Q: 采样率不对？
A: 检查 `timerInterval` 配置，确保定时器正常运行。

---

## 下一步

采集数据后，使用Python脚本处理：

```bash
# 处理采样数据，计算速度/加速度
python slider_trajectory_dl/scripts/process_real_sampling.py \
    --input_dir ./data/raw \
    --output_dir ./data/processed
```

Happy collecting! 🎉
