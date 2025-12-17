#!/usr/bin/env python3
"""
将标注数据（JSON格式）转换为训练数据（JSONL格式）

使用方法:
    python convert_to_jsonl.py --input_dir /Users/wilinz/IdeaProjects/chuanggao-kt/captcha_dataset/metadata --output_file training_data1.jsonl

参数说明:
    --input_dir: 标注数据目录（包含JSON文件）
    --output_file: 输出的JSONL文件路径
    --min_time: 最小总时长（毫秒），默认500
    --max_time: 最大总时长（毫秒），默认3000
    --min_points: 最小轨迹点数，默认10
"""

import json
import argparse
from pathlib import Path
from typing import List, Dict, Any


def validate_track_data(data: Dict[str, Any], min_time: int, max_time: int, min_points: int) -> tuple[bool, str]:
    """
    验证轨迹数据质量

    Args:
        data: JSON数据
        min_time: 最小总时长（毫秒）
        max_time: 最大总时长（毫秒）
        min_points: 最小轨迹点数

    Returns:
        (是否有效, 错误信息)
    """
    # 检查必需字段
    if 'tracks' not in data:
        return False, "缺少 'tracks' 字段"

    if 'targetDistance' not in data:
        return False, "缺少 'targetDistance' 字段"

    if 'canvasLength' not in data:
        return False, "缺少 'canvasLength' 字段"

    tracks = data['tracks']

    # 检查轨迹点数
    if len(tracks) < min_points:
        return False, f"轨迹点数不足 ({len(tracks)} < {min_points})"

    # 计算总时长
    total_time = sum(t.get('c', 0) for t in tracks)

    # 检查总时长
    if total_time < min_time:
        return False, f"总时长过短 ({total_time}ms < {min_time}ms)"

    if total_time > max_time:
        return False, f"总时长过长 ({total_time}ms > {max_time}ms)"

    # 检查轨迹点格式
    for i, track in enumerate(tracks):
        if 'a' not in track or 'b' not in track or 'c' not in track:
            return False, f"第 {i} 个轨迹点缺少必需字段 (a, b, c)"

    return True, ""


def convert_json_to_training_sample(data: Dict[str, Any]) -> str:
    """
    将JSON数据转换为训练样本

    Args:
        data: JSON数据

    Returns:
        训练样本字符串（JSONL格式）
    """
    # 提取必要信息
    distance = data['targetDistance']
    canvas = data['canvasLength']
    tracks = data['tracks']

    # 构建轨迹字符串
    # 格式: a,b,c;a,b,c;...
    track_str = ';'.join([f"{t['a']},{t['b']},{t['c']}" for t in tracks])

    # 构建训练样本
    # 格式: <|input|>distance:{distance},canvas:{canvas}<|output|>{track_str}<|end|>
    text = f"<|input|>distance:{distance},canvas:{canvas}<|output|>{track_str}<|end|>"

    # 返回JSONL格式
    return json.dumps({"text": text}, ensure_ascii=False)


def convert_to_jsonl(
    input_dir: str,
    output_file: str,
    min_time: int = 500,
    max_time: int = 3000,
    min_points: int = 10
) -> None:
    """
    将标注数据转换为JSONL格式

    Args:
        input_dir: 标注数据目录
        output_file: 输出文件路径
        min_time: 最小总时长（毫秒）
        max_time: 最大总时长（毫秒）
        min_points: 最小轨迹点数
    """
    input_path = Path(input_dir)
    output_path = Path(output_file)

    # 检查输入目录
    if not input_path.exists():
        print(f"❌ 错误: 输入目录不存在: {input_dir}")
        return

    if not input_path.is_dir():
        print(f"❌ 错误: 输入路径不是目录: {input_dir}")
        return

    # 获取所有JSON文件
    json_files = list(input_path.glob("*.json"))

    if not json_files:
        print(f"❌ 错误: 在 {input_dir} 中未找到JSON文件")
        return

    print(f"📂 输入目录: {input_dir}")
    print(f"📄 输出文件: {output_file}")
    print(f"📊 找到 {len(json_files)} 个JSON文件")
    print()
    print("🔍 质量过滤条件:")
    print(f"   - 总时长: {min_time}-{max_time}ms")
    print(f"   - 最小点数: {min_points}")
    print()
    print("=" * 70)

    # 统计信息
    stats = {
        'total': 0,
        'valid': 0,
        'invalid': 0,
        'errors': []
    }

    # 创建输出目录（如果不存在）
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # 转换数据
    with open(output_path, 'w', encoding='utf-8') as out_f:
        for json_file in sorted(json_files):
            stats['total'] += 1

            try:
                # 读取JSON文件
                with open(json_file, 'r', encoding='utf-8') as in_f:
                    data = json.load(in_f)

                # 验证数据质量
                is_valid, error_msg = validate_track_data(data, min_time, max_time, min_points)

                if is_valid:
                    # 转换为训练样本
                    training_sample = convert_json_to_training_sample(data)

                    # 写入JSONL文件
                    out_f.write(training_sample + '\n')

                    stats['valid'] += 1
                    print(f"✅ {json_file.name}")
                else:
                    stats['invalid'] += 1
                    stats['errors'].append((json_file.name, error_msg))
                    print(f"⚠️  {json_file.name}: {error_msg}")

            except json.JSONDecodeError as e:
                stats['invalid'] += 1
                error = f"JSON解析错误: {e}"
                stats['errors'].append((json_file.name, error))
                print(f"❌ {json_file.name}: {error}")

            except Exception as e:
                stats['invalid'] += 1
                error = f"处理错误: {e}"
                stats['errors'].append((json_file.name, error))
                print(f"❌ {json_file.name}: {error}")

    # 输出统计信息
    print()
    print("=" * 70)
    print("📊 转换统计:")
    print(f"   总文件数: {stats['total']}")
    print(f"   ✅ 有效: {stats['valid']}")
    print(f"   ⚠️  无效: {stats['invalid']}")
    print()

    if stats['valid'] > 0:
        print(f"✅ 成功生成训练数据: {output_file}")
        print(f"   包含 {stats['valid']} 个训练样本")
    else:
        print("❌ 未生成任何有效的训练样本")

    # 显示错误详情
    if stats['errors']:
        print()
        print("⚠️  无效文件详情:")
        for filename, error in stats['errors']:
            print(f"   - {filename}: {error}")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='将标注数据（JSON格式）转换为训练数据（JSONL格式）',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 基本用法
  python convert_to_jsonl.py --input_dir captcha_dataset/metadata --output_file training_data.jsonl

  # 自定义质量过滤条件
  python convert_to_jsonl.py \\
      --input_dir captcha_dataset/metadata \\
      --output_file training_data.jsonl \\
      --min_time 800 \\
      --max_time 2000 \\
      --min_points 15

  # 使用相对路径
  python convert_to_jsonl.py \\
      --input_dir ../captcha_dataset/metadata \\
      --output_file ./training_data.jsonl
        """
    )

    parser.add_argument(
        '--input_dir',
        type=str,
        required=True,
        help='标注数据目录（包含JSON文件）'
    )

    parser.add_argument(
        '--output_file',
        type=str,
        required=True,
        help='输出的JSONL文件路径'
    )

    parser.add_argument(
        '--min_time',
        type=int,
        default=500,
        help='最小总时长（毫秒），默认500'
    )

    parser.add_argument(
        '--max_time',
        type=int,
        default=5000,
        help='最大总时长（毫秒），默认3000'
    )

    parser.add_argument(
        '--min_points',
        type=int,
        default=10,
        help='最小轨迹点数，默认10'
    )

    args = parser.parse_args()

    # 转换数据
    convert_to_jsonl(
        input_dir=args.input_dir,
        output_file=args.output_file,
        min_time=args.min_time,
        max_time=args.max_time,
        min_points=args.min_points
    )


if __name__ == "__main__":
    main()