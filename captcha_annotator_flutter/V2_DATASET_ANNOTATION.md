# V2数据集标注指南

## 概述

V2数据集标注器结合了验证码图片标注和双序列真实采样功能，相比V1具有以下优势：

### V1 vs V2 对比

| 特性 | V1标注器 | V2标注器 |
|------|---------|---------|
| **采样方式** | 事件触发（不均匀） | 定时器5ms + 事件触发（双序列） |
| **数据完整性** | 仅事件点（~30点） | 定时器~300点 + 事件点~30点 |
| **时间准确性** | 间隔20-300ms不等 | 定时器固定5ms间隔 |
| **速度/加速度** | 不准确 | 真实且准确 |
| **训练效果** | 基础 | 更好的时间分布和轨迹细节 |

---

## 快速开始

### 1. 运行应用

```bash
cd captcha_annotator_flutter
flutter run
```

### 2. 选择数据集

在主界面：
1. 点击 "Select Dataset Folder" 选择验证码数据集目录
2. 或直接输入路径，如：`/Users/xxx/captcha_dataset`

数据集结构：
```
captcha_dataset/
├── images/
│   ├── {id}_big.png    # 背景图
│   └── {id}_small.png  # 滑块图
└── metadata/
    └── {id}.json       # 元数据
```

### 3. 启动V2标注器

点击绿色的 **"V2 数据集标注"** 按钮

---

## 标注流程

### 界面说明

1. **进度卡片**：显示当前进度（如：3 / 150）和验证码ID
2. **图片区域**：显示背景大图和滑块小图
3. **滑块区域**：拖动滑块到目标位置
4. **统计卡片**：显示采样统计（总时长、点数、采样率等）
5. **双序列图表**：可视化对比定时器采样和事件采样
6. **操作按钮**：上一个、保存、跳过、下一个

### 标注步骤

1. **观察图片**：查看背景图和滑块图，确定目标位置
2. **拖动滑块**：
   - 点击并拖动滑块
   - 定时器会自动每5ms记录一次位置
   - 同时记录onPanUpdate事件触发点
3. **查看统计**：拖动完成后会显示采样统计和图表
4. **保存标注**：点击 "保存标注" 按钮
5. **自动跳转**：保存后自动加载下一个验证码

---

## 数据格式

### V2 JSON格式

```json
{
  "id": "captcha_001",
  "timestamp": 1234567890000,
  "bigImage": {
    "file": "captcha_001_big.png",
    "width": 280,
    "height": 150
  },
  "smallImage": {
    "file": "captcha_001_small.png",
    "width": 50,
    "height": 50
  },
  "yHeight": 0,
  "canvasLength": 280,
  "targetDistance": 145,

  "timerTracks": [
    {"x": 0, "y": 0, "timestamp": 0, "interval": 0},
    {"x": 1, "y": 0, "timestamp": 5, "interval": 5},
    {"x": 3, "y": 0, "timestamp": 10, "interval": 5},
    ...
  ],

  "eventTracks": [
    {"x": 0, "y": 0, "timestamp": 0, "interval": 0},
    {"x": 5, "y": 1, "timestamp": 23, "interval": 23},
    {"x": 12, "y": 2, "timestamp": 47, "interval": 24},
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

### 字段说明

- `timerTracks`: 定时器5ms均匀采样序列
  - 200Hz采样率，1.5秒约300个点
  - 真实的鼠标位置，不是插值

- `eventTracks`: onPanUpdate事件触发序列
  - 不均匀间隔（约20-60ms）
  - 反映系统真实的事件触发特性

- `metadata`: 采样元数据
  - `totalTime`: 总时长（ms）
  - `timerPointCount`: 定时器采样点数
  - `eventPointCount`: 事件触发点数
  - `avgEventInterval`: 平均事件间隔
  - `samplingRate`: 实际采样率（Hz）

---

## 数据处理

### 计算速度和加速度

```bash
cd slider_trajectory_dl

python scripts/process_real_sampling.py \
    --input_dir ../captcha_dataset/metadata \
    --output_dir ./data/processed_v2
```

输出包含：
- `vx, vy`: X/Y方向速度 (px/s)
- `ax, ay`: X/Y方向加速度 (px/s²)
- `speed`: 速度大小
- `acceleration`: 加速度大小

### 训练模型

使用处理后的V2数据训练模型：

```bash
python scripts/train.py --data_dir ./data/processed_v2
```

---

## 快捷键

| 按钮 | 功能 | 说明 |
|------|------|------|
| 上一个 | 加载上一个验证码 | 不保存当前标注 |
| 保存标注 | 保存当前轨迹 | 需要先拖动滑块 |
| 跳过 | 跳过当前验证码 | 不保存，直接下一个 |
| 下一个 | 加载下一个验证码 | 不保存当前标注 |

---

## 标注技巧

### 1. 真实拖动
- **像人一样拖动**：不要匀速移动，要有加减速
- **包含初始延迟**：拖动前稍微停顿一下
- **自然结束**：到达目标后可以微调

### 2. 速度控制
- **不要太快**：太快会导致采样点少，细节丢失
- **不要太慢**：太慢不真实，且数据量过大
- **推荐时长**：1-2秒是理想范围

### 3. 质量检查
标注后检查统计卡片：
- ✅ 总时长：800-2000ms
- ✅ 定时器点数：160-400个
- ✅ 事件点数：20-50个
- ✅ 采样率：接近200Hz

---

## 常见问题

### Q: 图片加载失败？
A: 检查数据集路径是否正确，images目录是否存在

### Q: 保存按钮不可用？
A: 需要先拖动滑块才能保存

### Q: 采样率偏低？
A: 检查timerInterval配置（应该是5ms）

### Q: V1数据如何转换为V2？
A: V2会自动兼容V1数据，但不会有双序列。建议重新标注以获得完整的V2数据。

### Q: 可以修改采样间隔吗？
A: 可以，在 `captcha_annotator_controller_v2.dart` 中修改 `timerInterval`：
```dart
static const int timerInterval = 5;  // 1, 5, 或 10
```

---

## 性能优化

### CPU占用
- 5ms定时器占用 < 1% CPU
- 可在低端设备上流畅运行

### 内存占用
- 单个轨迹约5KB
- 可同时加载数千个轨迹

---

## 下一步

1. **标注数据集**：使用V2标注器完成所有验证码标注
2. **处理数据**：运行处理脚本计算速度/加速度
3. **训练模型**：使用V2数据训练轨迹生成模型
4. **对比效果**：与V1模型对比，验证改进效果

---

## 技术支持

遇到问题？
1. 查看Flutter控制台日志
2. 检查数据集结构
3. 确认JSON格式正确
4. 重新运行build_runner生成代码

Happy annotating! 🎉
