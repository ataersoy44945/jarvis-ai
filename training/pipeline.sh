#!/usr/bin/env bash
# Full loop: export rated chats -> QLoRA train -> swap adapter -> restart vLLM -> smoke test.
# Safe to run from cron; it skips when there isn't enough new data.
#   ./pipeline.sh            normal run
#   ./pipeline.sh --force    train even if not enough new data
set -euo pipefail
cd "$(dirname "$0")"
source ./jarvis.env
mkdir -p logs adapters data
LOG=logs/pipeline.log
exec > >(tee -a "$LOG") 2>&1
now() { date -Is 2>/dev/null || date "+%Y-%m-%dT%H:%M:%S%z"; }
echo "=== $(now) pipeline start (backend ${TRAIN_BACKEND:-vllm})"

# Don't run twice at the same time. flock is Linux; mkdir is the macOS fallback.
if command -v flock >/dev/null 2>&1; then
  exec 9>.pipeline.lock
  flock -n 9 || { echo "another pipeline run is active — exit"; exit 0; }
else
  if ! mkdir .pipeline.lockdir 2>/dev/null; then
    echo "another pipeline run is active — exit"; exit 0
  fi
  trap 'rmdir .pipeline.lockdir 2>/dev/null || true' EXIT
fi

if command -v python >/dev/null 2>&1; then PY=python; else PY=python3; fi
"$PY" export_dataset.py --db "$JARVIS_DB"
N=$(wc -l < data/train.jsonl)
LAST=$(cat adapters/.last_count 2>/dev/null || echo 0)
echo "examples: $N (last trained on $LAST)"
if [[ ${1:-} != --force ]]; then
  (( N >= MIN_EXAMPLES )) || { echo "need >= $MIN_EXAMPLES examples — skip"; exit 0; }
  (( N - LAST >= MIN_NEW_EXAMPLES )) || { echo "need >= $MIN_NEW_EXAMPLES new examples — skip"; exit 0; }
fi

VER=$(printf "v%03d" $(( $(ls -d adapters/v* 2>/dev/null | wc -l) + 1 )))
echo "training adapter $VER"
# Free the GPU / unified memory for training
if [[ "${TRAIN_BACKEND:-vllm}" == "mlx" ]]; then
  SERVE=(./serve_mlx.sh)
  TRAIN=(./train_mlx.sh --out "adapters/$VER")
  SMOKE_MODEL="${MLX_SERVED_MODEL:-default_model}"
else
  SERVE=(./serve_vllm.sh)
  TRAIN=(python train_lora.py --base "$BASE_MODEL" --out "adapters/$VER" --max-len 2048)
  SMOKE_MODEL="$SERVED_NAME"
fi
"${SERVE[@]}" --stop
"${TRAIN[@]}"

PREV=$(readlink adapters/current 2>/dev/null || true)
ln -sfn "$VER" adapters/current
if "${SERVE[@]}" && curl -sf "http://127.0.0.1:$VLLM_PORT/v1/chat/completions" \
     -H 'Content-Type: application/json' \
     -d "{\"model\":\"$SMOKE_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Merhaba Jarvis\"}],\"max_tokens\":40}" \
     | "$PY" -c 'import sys,json; r=json.load(sys.stdin); print("smoke:", r["choices"][0]["message"]["content"][:120])'; then
  echo "$N" > adapters/.last_count
  echo "=== $(now) promoted $VER"
else
  echo "smoke test failed — rolling back to ${PREV:-base model}"
  if [[ -n $PREV ]]; then ln -sfn "$PREV" adapters/current; else rm -f adapters/current; fi
  "${SERVE[@]}"
  exit 1
fi
