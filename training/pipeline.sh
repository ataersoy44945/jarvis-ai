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
echo "=== $(date -Is) pipeline start"

# Don't run twice at the same time
exec 9>.pipeline.lock
flock -n 9 || { echo "another pipeline run is active — exit"; exit 0; }

python export_dataset.py --db "$JARVIS_DB"
N=$(wc -l < data/train.jsonl)
LAST=$(cat adapters/.last_count 2>/dev/null || echo 0)
echo "examples: $N (last trained on $LAST)"
if [[ ${1:-} != --force ]]; then
  (( N >= MIN_EXAMPLES )) || { echo "need >= $MIN_EXAMPLES examples — skip"; exit 0; }
  (( N - LAST >= MIN_NEW_EXAMPLES )) || { echo "need >= $MIN_NEW_EXAMPLES new examples — skip"; exit 0; }
fi

VER=$(printf "v%03d" $(( $(ls -d adapters/v* 2>/dev/null | wc -l) + 1 )))
echo "training adapter $VER"
# Free the GPU for training
./serve_vllm.sh --stop
python train_lora.py --base "$BASE_MODEL" --out "adapters/$VER" --max-len 2048

PREV=$(readlink adapters/current 2>/dev/null || true)
ln -sfn "$VER" adapters/current
if ./serve_vllm.sh && curl -sf "http://127.0.0.1:$VLLM_PORT/v1/chat/completions" \
     -H 'Content-Type: application/json' \
     -d "{\"model\":\"$SERVED_NAME\",\"messages\":[{\"role\":\"user\",\"content\":\"Merhaba Jarvis\"}],\"max_tokens\":40}" \
     | python -c 'import sys,json; r=json.load(sys.stdin); print("smoke:", r["choices"][0]["message"]["content"][:120])'; then
  echo "$N" > adapters/.last_count
  echo "=== $(date -Is) promoted $VER"
else
  echo "smoke test failed — rolling back to ${PREV:-base model}"
  if [[ -n $PREV ]]; then ln -sfn "$PREV" adapters/current; else rm -f adapters/current; fi
  ./serve_vllm.sh
  exit 1
fi
