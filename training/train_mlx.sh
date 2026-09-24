#!/usr/bin/env bash
# LoRA on Apple Silicon via MLX. Reads export_dataset.py output and writes adapters/vNNN.
#   ./train_mlx.sh --out adapters/v001
set -euo pipefail
cd "$(dirname "$0")"
source ./jarvis.env

OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
[[ -n "$OUT" ]] || { echo "usage: ./train_mlx.sh --out adapters/vNNN" >&2; exit 1; }

PY=".venv-mlx/bin/python"
LORA=".venv-mlx/bin/mlx_lm.lora"
[[ -x "$PY" && -x "$LORA" ]] || {
  echo "missing training/.venv-mlx — python -m venv .venv-mlx && pip install -r requirements-mlx.txt" >&2
  exit 1
}

"$PY" - << 'PY'
from pathlib import Path

train_path = Path("data/train.jsonl")
eval_path = Path("data/eval.jsonl")
train = [ln for ln in train_path.read_text(encoding="utf-8").splitlines() if ln.strip()] if train_path.exists() else []
valid = [ln for ln in eval_path.read_text(encoding="utf-8").splitlines() if ln.strip()] if eval_path.exists() else []
if not train:
    raise SystemExit("No training data in data/train.jsonl. Run export_dataset.py first.")
if not valid:
    # Keep at least one train row. A few held-out lines only when the set can spare them.
    hold = min(4, len(train) // 5) if len(train) >= 5 else 0
    if hold:
        valid, train = train[:hold], train[hold:]
        print(f"eval empty — held out {hold} examples into valid.jsonl")
    else:
        valid = list(train)
        print("eval empty and train is too small to split — copied train into valid.jsonl")
out = Path("data/mlx")
out.mkdir(parents=True, exist_ok=True)
(out / "train.jsonl").write_text("\n".join(train) + "\n", encoding="utf-8")
(out / "valid.jsonl").write_text("\n".join(valid) + "\n", encoding="utf-8")
print(f"mlx data: train={len(train)} valid={len(valid)} -> {out}")
PY

ITERS="${MLX_ITERS:-100}"
echo "mlx lora: model=$MLX_BASE_MODEL out=$OUT iters=$ITERS"
exec "$LORA" \
  --model "$MLX_BASE_MODEL" \
  --train \
  --data data/mlx \
  --mask-prompt \
  --batch-size 1 \
  --grad-checkpoint \
  --max-seq-length 1024 \
  --num-layers 8 \
  --iters "$ITERS" \
  --val-batches 1 \
  --steps-per-eval 20 \
  --save-every "$ITERS" \
  --adapter-path "$OUT"
