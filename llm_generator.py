#!/usr/bin/env python3
"""
使用微调后的Qwen2.5-0.5B模型生成滑块轨迹
"""
import datetime
import json

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel
from pathlib import Path
import re

class LLMTrajectoryGenerator:
    """基于LLM的轨迹生成器"""

    def __init__(self, model_path=None, device=None):
        """
        Args:
            model_path: 微调后的模型路径
            device: 设备（auto/cpu/cuda/mps）
        """
        if model_path is None:
            model_path = Path(__file__).parent / "models/final_model"

        self.model_path = Path(model_path)

        if device is None:
            if torch.cuda.is_available():
                device = "cuda"
            elif torch.backends.mps.is_available():
                device = "mps"
            else:
                device = "cpu"

        self.device = device
        print(f"🤖 Loading LLM model from {self.model_path}")
        print(f"📍 Device: {self.device}")

        # 加载tokenizer和模型
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_path, trust_remote_code=True)
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            device_map=device,
            dtype=torch.float16 if device in ["cuda", "mps"] else torch.float32,
            trust_remote_code=True  # Qwen需要信任远程代码
        )
        self.model.eval()
        print(f"✅ Model loaded successfully")

    def generate(self, target_distance, canvas_length=280, temperature=0.8, top_p=0.95):
        """
        生成轨迹

        Args:
            target_distance: 目标距离
            canvas_length: 画布长度
            temperature: 采样温度（越高越多样）
            top_p: nucleus sampling参数

        Returns:
            tracks: List[Dict] - 轨迹点 [{'a': x, 'b': y, 'c': dt}, ...]
        """
        # 构建输入
        input_text = f"<|input|>distance:{int(target_distance)},canvas:{canvas_length}<|output|>"

        # Token化
        inputs = self.tokenizer(input_text, return_tensors="pt").to(self.device)

        # 生成
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_new_tokens=300,
                temperature=temperature,
                top_p=top_p,
                do_sample=True,
                pad_token_id=self.tokenizer.eos_token_id,
                eos_token_id=self.tokenizer.encode("<|end|>")[0] if "<|end|>" in self.tokenizer.get_vocab() else self.tokenizer.eos_token_id
            )

        # 解码
        generated_text = self.tokenizer.decode(outputs[0], skip_special_tokens=False)

        # 解析轨迹
        tracks = self._parse_trajectory(generated_text, target_distance)

        return tracks

    def _parse_trajectory(self, text, target_distance):
        """
        从生成的文本中解析轨迹

        格式: <|output|>0,0,0;5,-2,30;12,-3,28;...<|end|>
        """
        # 提取output部分
        match = re.search(r'<\|output\|>(.*?)(?:<\|end\|>|$)', text)
        if not match:
            print(f"⚠️  Failed to parse output, using fallback")
            return [{'a': 0, 'b': 0, 'c': 0}]

        output_str = match.group(1).strip()

        # 解析轨迹点
        tracks = []
        points = output_str.split(';')

        for point_str in points:
            point_str = point_str.strip()
            if not point_str:
                continue

            try:
                parts = point_str.split(',')
                if len(parts) == 3:
                    x = int(float(parts[0]))
                    y = int(float(parts[1]))
                    dt = int(float(parts[2]))

                    # 限制范围
                    x = max(0, min(x, int(target_distance * 1.1)))
                    y = max(-30, min(5, y))
                    dt = max(1, min(400, dt))

                    tracks.append({'a': x, 'b': y, 'c': dt})
            except (ValueError, IndexError) as e:
                # 跳过无效点
                continue

        # 确保至少有起点
        if not tracks or tracks[0]['a'] != 0:
            tracks.insert(0, {'a': 0, 'b': 0, 'c': 0})

        # 确保终点正确
        if len(tracks) > 1:
            tracks[-1]['a'] = target_distance

        return tracks

def test_generator():
    """测试生成器"""
    print("🧪 Testing LLM Trajectory Generator")
    print("=" * 70)

    generator = LLMTrajectoryGenerator()

    # 测试生成
    for i in range(3):
        print(f"\n测试 {i+1}:")
        t = datetime.datetime.now()
        tracks = generator.generate(target_distance=60*(i+1), temperature=0.8)
        print(f"  生成点数: {len(tracks)}")
        print(f"  总时间: {sum(t['c'] for t in tracks)}ms")
        print(f"  点: {json.dumps(tracks)}")
        tt = datetime.datetime.now() - t
        print(f"  <time>: {tt}")

if __name__ == "__main__":
    test_generator()
