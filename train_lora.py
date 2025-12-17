#!/usr/bin/env python3
"""
使用LoRA微调Qwen2.5-0.5B生成滑块验证码轨迹
"""

import os
import torch
from datasets import load_dataset
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    TrainingArguments,
    Trainer,
    DataCollatorForLanguageModeling
)
from peft import (
    LoraConfig,
    get_peft_model,
    prepare_model_for_kbit_training
)
from pathlib import Path

# 设置
MODEL_NAME = "Qwen/Qwen2.5-0.5B-Instruct"  # 阿里通义千问2.5 (0.5B) - 2024年9月发布
OUTPUT_DIR = Path(__file__).parent / "models"
DATA_FILE = Path(__file__).parent / "training_data.jsonl"

def tokenize_function(examples, tokenizer):
    """Token化文本"""
    return tokenizer(
        examples["text"],
        truncation=True,
        max_length=512,
        padding="max_length"
    )

def main():
    print("🚀 Starting LoRA fine-tuning for slider trajectory generation")
    print("=" * 70)

    # 1. 加载数据
    print(f"\n📂 Loading dataset from {DATA_FILE}")
    dataset = load_dataset("json", data_files=str(DATA_FILE), split="train")
    print(f"✅ Loaded {len(dataset)} samples")

    # 分割训练集和验证集
    dataset = dataset.train_test_split(test_size=0.1, seed=42)
    train_dataset = dataset["train"]
    eval_dataset = dataset["test"]
    print(f"📊 Train: {len(train_dataset)}, Eval: {len(eval_dataset)}")

    # 2. 加载Tokenizer和模型
    print(f"\n🤖 Loading model: {MODEL_NAME}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

    # 设置pad_token（Qwen2.5已有pad_token，但仍确保设置）
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        device_map="auto",
        torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
        trust_remote_code=True  # Qwen需要信任远程代码
    )
    print(f"✅ Model loaded on device: {model.device}")

    # 3. Token化数据集
    print("\n🔤 Tokenizing dataset...")
    tokenized_train = train_dataset.map(
        lambda x: tokenize_function(x, tokenizer),
        batched=True,
        remove_columns=["text"]
    )
    tokenized_eval = eval_dataset.map(
        lambda x: tokenize_function(x, tokenizer),
        batched=True,
        remove_columns=["text"]
    )
    print("✅ Tokenization complete")

    # 4. 配置LoRA
    print("\n⚙️  Configuring LoRA...")
    lora_config = LoraConfig(
        r=16,                   # LoRA rank (Qwen用16效果更好)
        lora_alpha=32,          # LoRA alpha
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],  # Qwen2.5的attention和FFN层
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM"
    )

    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    # 5. 训练参数
    training_args = TrainingArguments(
        output_dir=str(OUTPUT_DIR),
        num_train_epochs=10,
        per_device_train_batch_size=4,
        per_device_eval_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        fp16=False,  # MacBook不支持CUDA，使用float32
        logging_steps=50,
        save_steps=200,
        eval_steps=200,
        eval_strategy="steps",  # 新版本使用eval_strategy而非evaluation_strategy
        save_total_limit=3,
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        greater_is_better=False,
        warmup_steps=100,
        report_to="none",
        remove_unused_columns=False
    )

    # 6. 数据整理器
    data_collator = DataCollatorForLanguageModeling(
        tokenizer=tokenizer,
        mlm=False  # Causal LM不使用MLM
    )

    # 7. 创建Trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_train,
        eval_dataset=tokenized_eval,
        data_collator=data_collator
    )

    # 8. 开始训练
    print("\n🎯 Starting training...")
    print("=" * 70)
    trainer.train()

    # 9. 保存最终模型
    print("\n💾 Saving final model...")
    model.save_pretrained(OUTPUT_DIR / "final_model")
    tokenizer.save_pretrained(OUTPUT_DIR / "final_model")
    print(f"✅ Model saved to {OUTPUT_DIR / 'final_model'}")

    print("\n🎉 Training complete!")
    print("=" * 70)

if __name__ == "__main__":
    main()
