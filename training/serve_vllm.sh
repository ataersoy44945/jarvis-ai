#!/usr/bin/env bash
# Start (or restart) vLLM with the current Jarvis adapter. OpenAI-compatible API on :$VLLM_PORT/v1
#   ./serve_vllm.sh            start in background (logs/vllm.log)
#   ./serve_vllm.sh --fg       foreground
#   ./serve_vllm.sh --stop
set -euo pipefail
cd "$(dirname "$0")"
source ./jarvis.env
PID_FILE=.vllm.pid
mkdir -p logs

stop() {
  if [[ -f $PID_FILE ]] && kill -0 "$(cat $PID_FILE)" 2>/dev/null; then
    echo "stopping vLLM (pid $(cat $PID_FILE))"
    kill "$(cat $PID_FILE)"
    for _ in $(seq 60); do kill -0 "$(cat $PID_FILE)" 2>/dev/null || break; sleep 1; done
  fi
  rm -f $PID_FILE
}

[[ ${1:-} == --stop ]] && { stop; exit 0; }
stop

ARGS=(serve "$BASE_MODEL" --host 0.0.0.0 --port "$VLLM_PORT"
      --gpu-memory-utilization "$GPU_MEM_UTIL" --max-model-len "$MAX_MODEL_LEN")
if [[ -e adapters/current ]]; then
  ADAPTER=$(readlink -f adapters/current)
  echo "serving $BASE_MODEL + adapter $ADAPTER as '$SERVED_NAME'"
  ARGS+=(--served-model-name "${SERVED_NAME}-base" --enable-lora
         --lora-modules "$SERVED_NAME=$ADAPTER" --max-lora-rank "$MAX_LORA_RANK")
else
  echo "no adapter yet — serving plain $BASE_MODEL as '$SERVED_NAME'"
  ARGS+=(--served-model-name "$SERVED_NAME")
fi

if [[ ${1:-} == --fg ]]; then exec vllm "${ARGS[@]}"; fi
nohup vllm "${ARGS[@]}" > logs/vllm.log 2>&1 &
echo $! > $PID_FILE

echo -n "waiting for vLLM"
for _ in $(seq 300); do
  if curl -sf "http://127.0.0.1:$VLLM_PORT/v1/models" >/dev/null; then echo " ready"; exit 0; fi
  kill -0 "$(cat $PID_FILE)" 2>/dev/null || { echo " crashed — see logs/vllm.log"; exit 1; }
  echo -n "."; sleep 2
done
echo " timeout — see logs/vllm.log"; exit 1
