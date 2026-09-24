"""QLoRA fine-tune of an open chat model on Jarvis data. Produces a LoRA adapter that vLLM serves.

    python train_lora.py --train data/train.jsonl --out adapters/v001

Defaults target a single 24 GB GPU (RTX 3090/4090, A10, L4) with Qwen2.5-7B-Instruct.
Smaller GPU (12–16 GB)? --base Qwen/Qwen2.5-3B-Instruct
Only the final assistant message of each example contributes to the loss.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import torch
from datasets import Dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    DataCollatorForSeq2Seq,
    Trainer,
    TrainingArguments,
)


def load_jsonl(path: Path) -> list[dict]:
    if not path or not path.exists():
        return []
    return [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]


def build_tokenize(tok, max_len: int):
    def tokenize(ex: dict) -> dict:
        msgs = ex["messages"]
        prompt = tok.apply_chat_template(msgs[:-1], tokenize=False, add_generation_prompt=True)
        full = tok.apply_chat_template(msgs, tokenize=False)
        p_ids = tok(prompt, add_special_tokens=False)["input_ids"]
        f_ids = tok(full, add_special_tokens=False)["input_ids"]
        if f_ids[: len(p_ids)] != p_ids:  # template quirk — fall back to prompt + answer + eos
            f_ids = p_ids + tok(msgs[-1]["content"], add_special_tokens=False)["input_ids"] + [tok.eos_token_id]
        # keep the end (the answer) if too long: drop oldest context tokens
        if len(f_ids) > max_len:
            cut = len(f_ids) - max_len
            f_ids, p_len = f_ids[cut:], max(len(p_ids) - cut, 0)
        else:
            p_len = len(p_ids)
        labels = [-100] * p_len + f_ids[p_len:]
        return {"input_ids": f_ids, "attention_mask": [1] * len(f_ids), "labels": labels}

    return tokenize


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="Qwen/Qwen2.5-7B-Instruct")
    ap.add_argument("--train", type=Path, default=Path("data/train.jsonl"))
    ap.add_argument("--eval", type=Path, default=Path("data/eval.jsonl"))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--epochs", type=float, default=3)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--rank", type=int, default=16)
    ap.add_argument("--alpha", type=int, default=32)
    ap.add_argument("--max-len", type=int, default=2048)
    ap.add_argument("--batch", type=int, default=2)
    ap.add_argument("--grad-accum", type=int, default=8)
    ap.add_argument("--no-4bit", action="store_true", help="plain bf16 LoRA (needs more VRAM)")
    args = ap.parse_args()

    train_rows = load_jsonl(args.train)
    eval_rows = load_jsonl(args.eval)
    if not train_rows:
        raise SystemExit(f"No training data in {args.train}. Run export_dataset.py first.")
    print(f"train={len(train_rows)} eval={len(eval_rows)} base={args.base}")

    tok = AutoTokenizer.from_pretrained(args.base)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    tokenize = build_tokenize(tok, args.max_len)
    train_ds = Dataset.from_list(train_rows).map(tokenize, remove_columns=["messages"])
    eval_ds = Dataset.from_list(eval_rows).map(tokenize, remove_columns=["messages"]) if eval_rows else None

    quant = None
    if not args.no_4bit:
        quant = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
        )
    model = AutoModelForCausalLM.from_pretrained(
        args.base, quantization_config=quant, torch_dtype=torch.bfloat16, device_map="auto"
    )
    if quant:
        model = prepare_model_for_kbit_training(model, use_gradient_checkpointing=True)
    else:
        model.gradient_checkpointing_enable()
    model = get_peft_model(
        model,
        LoraConfig(
            r=args.rank,
            lora_alpha=args.alpha,
            lora_dropout=0.05,
            bias="none",
            task_type="CAUSAL_LM",
            target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        ),
    )
    model.print_trainable_parameters()

    steps_per_epoch = max(1, math.ceil(len(train_ds) / (args.batch * args.grad_accum)))
    targs = TrainingArguments(
        output_dir=str(args.out / "_checkpoints"),
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch,
        per_device_eval_batch_size=args.batch,
        gradient_accumulation_steps=args.grad_accum,
        learning_rate=args.lr,
        lr_scheduler_type="cosine",
        warmup_ratio=0.05,
        logging_steps=max(1, steps_per_epoch // 5),
        eval_strategy="epoch" if eval_ds else "no",
        save_strategy="no",
        bf16=True,
        optim="paged_adamw_8bit" if quant else "adamw_torch",
        report_to="none",
    )
    trainer = Trainer(
        model=model,
        args=targs,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        data_collator=DataCollatorForSeq2Seq(tok, padding=True, label_pad_token_id=-100),
    )
    trainer.train()
    metrics = trainer.evaluate() if eval_ds else {}

    args.out.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(args.out)  # adapter only (~100–300 MB)
    tok.save_pretrained(args.out)
    (args.out / "jarvis_train_info.json").write_text(
        json.dumps({"base": args.base, "train": len(train_rows), "eval": len(eval_rows),
                    "rank": args.rank, "epochs": args.epochs, "metrics": metrics}, indent=2)
    )
    print(f"Adapter saved to {args.out}")


if __name__ == "__main__":
    main()
