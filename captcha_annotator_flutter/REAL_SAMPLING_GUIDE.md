# 真实定时器采样方案

## 设计理念

**❌ 不要插值！要真实数据！**

插值生成的数据不是真实的鼠标轨迹，而是数学构造的。
真实采集方案使用定时器直接记录鼠标的真实位置。

---

## 双序列采集

### 序列1：定时器采样（均匀、真实）
```dart
Timer.periodic(Duration(milliseconds: 5), (timer) {
  // 每5ms记录一次真实位置
  recordPosition(currentX, currentY);
});
```

**特点**：
- ✅ 5ms均匀采样（200Hz采样率）
- ✅ 真实的鼠标位置，不是插值
- ✅ 完整的运动曲线

### 序列2：事件触发采样（系统特性）
```dart
onPanUpdate: (details) {
  // onPanUpdate触发时记录
  recordEventPosition(details.globalPosition);
}
```

**特点**：
- ✅ 浏览器/系统真实的事件触发时间
- ✅ 反映系统采样特性
- ✅ 事件间隔本身就是特征

---

## 数据结构

```json
{
  "id": "sample_001",
  "canvasLength": 280,
  "targetDistance": 145,

  "timerTracks": [
    {"x": 0, "y": 0, "timestamp": 0, "interval": 0},
    {"x": 1, "y": 0, "timestamp": 5, "interval": 5},
    {"x": 2, "y": 0, "timestamp": 10, "interval": 5},
    ...
  ],

  "eventTracks": [
    {"x": 0, "y": 0, "timestamp": 0, "interval": 0},
    {"x": 5, "y": 1, "timestamp": 23, "interval": 23},
    {"x": 12, "y": 2, "timestamp": 45, "interval": 22},
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

---

## 采样率选择

| 间隔 | 采样率 | 1秒点数 | 1.5秒总点数 | 推荐场景 |
|------|--------|---------|-------------|----------|
| 1ms  | 1000Hz | 1000    | 1500        | 研究级精度（数据量大）|
| 5ms  | 200Hz  | 200     | 300         | **推荐** 平衡精度和数据量 |
| 10ms | 100Hz  | 100     | 150         | 低端设备 |

**推荐使用 5ms**：
- ✅ 足够捕捉人类运动细节（人类反应时间~200ms）
- ✅ 数据量适中（~300点/1.5秒）
- ✅ 低性能开销

---

## 使用方法

### 1. 使用新控制器

```dart
import 'package:captcha_annotator_flutter/controllers/captcha_controller_v2.dart';

final controller = Get.put(CaptchaControllerV2());
```

### 2. 绑定手势

```dart
GestureDetector(
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
)
```

### 3. 导出数据

```dart
final data = controller.exportData(
  id: 'sample_001',
  canvasLength: 280,
  targetDistance: 145,
);

// 保存为JSON
final json = jsonEncode(data.toJson());
```

---

## 数据处理

### 计算速度和加速度

```bash
python scripts/process_real_sampling.py \
    --input_dir ./data/raw \
    --output_dir ./data/processed
```

输出包含：
- `vx, vy`: X/Y方向速度 (px/s)
- `ax, ay`: X/Y方向加速度 (px/s²)
- `speed`: 速度大小
- `acceleration`: 加速度大小

---

## 特征提取

处理后的数据包含丰富的特征：

### 时间特征
- 总时长
- 定时器采样点数
- 事件触发点数
- 平均事件间隔
- 事件间隔标准差

### 速度特征
- 最大速度
- 平均速度
- 速度标准差

### 加速度特征
- 最大加速度
- 平均加速度
- 加速度标准差

### 位置特征
- X范围
- Y范围
- Y标准差

---

## 对比：旧方案 vs 新方案

| 特性 | 旧方案（事件采样） | 新方案（定时器采样） |
|------|------------------|-------------------|
| **数据真实性** | ✅ 真实 | ✅ 真实 |
| **采样均匀性** | ❌ 不均匀（20-300ms） | ✅ 均匀（5ms） |
| **数据完整性** | ❌ 丢失中间细节 | ✅ 完整运动曲线 |
| **速度准确性** | ❌ 只有平均速度 | ✅ 瞬时速度 |
| **加速度准确性** | ❌ 不准确 | ✅ 准确 |
| **系统特性** | ✅ 保留事件间隔 | ✅ 双序列都保留 |
| **数据量** | 小（~30点） | 中（~300点） |

---

## 优势

### 1. 真实性
- 定时器记录的是**真实的鼠标位置**
- 不是插值构造的数据

### 2. 完整性
- 5ms采样捕捉完整的运动曲线
- 不会丢失中间的运动细节

### 3. 准确性
- 速度和加速度基于真实数据计算
- 使用中心差分法，更准确

### 4. 双重特征
- 定时器序列：连续运动特征
- 事件序列：系统采样特性

---

## 性能考虑

### CPU占用
5ms定时器的CPU占用很小：
- 每秒200次采样
- 每次只记录坐标和时间
- 总占用 < 1% CPU

### 内存占用
1.5秒轨迹的内存占用：
- ~300个点 × 16字节 ≈ 5KB
- 可以忽略不计

### 建议
- ✅ 使用5ms定时器（推荐）
- ⚠️ 避免1ms（数据量过大）
- ⚠️ 避免>10ms（精度不足）

---

## 下一步

1. **集成到采集器**
   - 替换旧的 CaptchaController
   - 使用 CaptchaControllerV2

2. **收集新数据**
   - 重新采集一批数据
   - 保存为V2格式

3. **对比训练效果**
   - 用旧数据训练一个模型
   - 用新数据训练一个模型
   - 对比生成质量

4. **评估改进**
   - 时间分布是否更准确？
   - 速度曲线是否更真实？
   - 整体效果是否更好？
