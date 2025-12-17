#!/usr/bin/env python3
"""
自动下载预训练模型脚本
从 GitHub Releases 下载最新的模型并解压到 models/final_model 目录
"""

import os
import sys
import zipfile
import shutil
from pathlib import Path
from urllib.request import urlopen, Request
import json

# GitHub 仓库信息
REPO_OWNER = "wilinz"
REPO_NAME = "slider_captcha_trajectory_gen"
MODEL_DIR = Path(__file__).parent / "models" / "final_model"


def get_latest_release():
    """获取最新的 release 信息"""
    api_url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/releases/latest"

    print("🔍 正在查询最新版本...")
    try:
        req = Request(api_url)
        req.add_header('User-Agent', 'Mozilla/5.0')

        with urlopen(req) as response:
            data = json.loads(response.read().decode())
            return data
    except Exception as e:
        print(f"❌ 获取 release 信息失败: {e}")
        return None


def find_model_asset(release_data):
    """从 release 中找到模型文件"""
    if not release_data or 'assets' not in release_data:
        return None

    # 查找模型文件（通常是 .zip 文件）
    for asset in release_data['assets']:
        name = asset['name'].lower()
        if 'model' in name and name.endswith('.zip'):
            return asset

    # 如果没有找到特定的模型文件，返回第一个 zip 文件
    for asset in release_data['assets']:
        if asset['name'].endswith('.zip'):
            return asset

    return None


def download_file(url, filename):
    """下载文件并显示进度"""
    print(f"📥 正在下载: {filename}")
    print(f"📍 URL: {url}")

    try:
        req = Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0')
        req.add_header('Accept', 'application/octet-stream')

        with urlopen(req) as response:
            total_size = int(response.headers.get('content-length', 0))
            block_size = 8192
            downloaded = 0

            with open(filename, 'wb') as f:
                while True:
                    buffer = response.read(block_size)
                    if not buffer:
                        break

                    downloaded += len(buffer)
                    f.write(buffer)

                    # 显示进度
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        bar_length = 40
                        filled = int(bar_length * downloaded / total_size)
                        bar = '█' * filled + '░' * (bar_length - filled)
                        print(f'\r  进度: [{bar}] {percent:.1f}% ({downloaded}/{total_size} bytes)', end='')
                    else:
                        print(f'\r  已下载: {downloaded} bytes', end='')

            print()  # 换行
            return True

    except Exception as e:
        print(f"\n❌ 下载失败: {e}")
        return False


def extract_zip(zip_path, extract_to):
    """解压 zip 文件"""
    print(f"📦 正在解压到: {extract_to}")

    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            # 获取所有文件列表
            file_list = zip_ref.namelist()
            total_files = len(file_list)

            # 解压所有文件
            for i, file in enumerate(file_list, 1):
                zip_ref.extract(file, extract_to)
                # 显示进度
                percent = (i / total_files) * 100
                print(f'\r  解压进度: {i}/{total_files} ({percent:.1f}%)', end='')

            print()  # 换行
            return True

    except Exception as e:
        print(f"\n❌ 解压失败: {e}")
        return False


def main():
    print("=" * 70)
    print("🤖 滑块轨迹生成模型自动下载工具")
    print("=" * 70)
    print()

    # 1. 检查模型目录是否已存在
    if MODEL_DIR.exists():
        print(f"⚠️  模型目录已存在: {MODEL_DIR}")
        response = input("是否要删除并重新下载？(y/N): ").strip().lower()
        if response == 'y':
            print("🗑️  正在删除旧模型...")
            shutil.rmtree(MODEL_DIR)
        else:
            print("❌ 取消下载")
            return

    # 2. 获取最新 release
    release_data = get_latest_release()
    if not release_data:
        print("❌ 无法获取 release 信息")
        print("\n💡 提示: 你也可以手动下载:")
        print(f"   https://github.com/{REPO_OWNER}/{REPO_NAME}/releases")
        return

    version = release_data.get('tag_name', 'unknown')
    print(f"✅ 找到最新版本: {version}")
    print(f"📝 发布说明: {release_data.get('name', 'N/A')}")
    print()

    # 3. 查找模型文件
    asset = find_model_asset(release_data)
    if not asset:
        print("❌ 未找到模型文件")
        print(f"\n💡 请手动访问: https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/latest")
        return

    download_url = asset['browser_download_url']
    filename = asset['name']
    file_size = asset['size']

    print(f"📦 模型文件: {filename}")
    print(f"📊 文件大小: {file_size / (1024*1024):.2f} MB")
    print()

    # 4. 下载文件
    temp_dir = Path(__file__).parent / "temp_download"
    temp_dir.mkdir(exist_ok=True)
    zip_path = temp_dir / filename

    if not download_file(download_url, zip_path):
        print("❌ 下载失败")
        return

    print("✅ 下载完成")
    print()

    # 5. 解压文件
    extract_temp = temp_dir / "extracted"
    extract_temp.mkdir(exist_ok=True)

    if not extract_zip(zip_path, extract_temp):
        print("❌ 解压失败")
        return

    print("✅ 解压完成")
    print()

    # 6. 移动到目标目录
    print("📂 正在整理文件...")

    # 查找解压后的模型目录
    # 可能的结构: extracted/final_model/* 或 extracted/*
    model_files = list(extract_temp.rglob("*.json")) + list(extract_temp.rglob("*.safetensors"))

    if not model_files:
        print("❌ 未找到模型文件")
        return

    # 找到包含模型文件的目录
    source_dir = None
    for model_file in model_files:
        if 'adapter_config.json' in model_file.name or 'config.json' in model_file.name:
            source_dir = model_file.parent
            break

    if not source_dir:
        source_dir = model_files[0].parent

    # 创建目标目录
    MODEL_DIR.parent.mkdir(parents=True, exist_ok=True)

    # 移动文件
    shutil.move(str(source_dir), str(MODEL_DIR))

    print(f"✅ 模型已安装到: {MODEL_DIR}")
    print()

    # 7. 清理临时文件
    print("🧹 正在清理临时文件...")
    shutil.rmtree(temp_dir)
    print("✅ 清理完成")
    print()

    # 8. 验证安装
    print("🔍 验证安装...")
    required_files = ['adapter_config.json', 'adapter_model.safetensors']
    all_present = True

    for required_file in required_files:
        file_path = MODEL_DIR / required_file
        if file_path.exists():
            print(f"  ✅ {required_file}")
        else:
            print(f"  ❌ {required_file} (未找到)")
            all_present = False

    print()

    if all_present:
        print("=" * 70)
        print("🎉 模型安装成功！")
        print("=" * 70)
        print()
        print("📝 下一步:")
        print("  1. 运行测试: python llm_generator.py")
        print("  2. 查看文档: README.md")
        print()
    else:
        print("⚠️  模型可能未完全安装，请检查文件")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n❌ 用户取消操作")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ 发生错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)