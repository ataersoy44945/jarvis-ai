#!/usr/bin/env bash
# Start (or restart) mlx_lm.server with the current Jarvis adapter.
# OpenAI-compatible API on 127.0.0.1:$VLLM_PORT/v1
#   ./serve_mlx.sh            start in background (logs/mlx.log)
#   ./serve_mlx.sh --fg       foreground
#   ./serve_mlx.sh --stop
set -euo pipefail
cd "$(dirname "$0")"
source ./jarvis.env
PID_FILE=.mlx.pid
mkdir -p logs
PY=".venv-mlx/bin/python"
[[ -x "$PY" ]] || {
  echo "missing training/.venv-mlx — python -m venv .venv-mlx && pip install -r requirements-mlx.txt" >&2
  exit 1
}

stop() {
  if [[ -f $PID_FILE ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "stopping mlx_lm.server (pid $(cat "$PID_FILE"))"
    kill "$(cat "$PID_FILE")"
    for _ in $(seq 60); do kill -0 "$(cat "$PID_FILE")" 2>/dev/null || break; sleep 1; done
  fi
  rm -f "$PID_FILE"
}

[[ ${1:-} == --stop ]] && { stop; exit 0; }
stop

ADAPTER=""
if [[ -e adapters/current ]]; then
  ADAPTER="$(python3 -c 'import os; print(os.path.realpath("adapters/current"))')"
  echo "serving $MLX_BASE_MODEL + adapter $ADAPTER (request model: ${MLX_SERVED_MODEL:-default_model})"
else
  echo "no adapter yet — serving plain $MLX_BASE_MODEL (request model: ${MLX_SERVED_MODEL:-default_model})"
fi

# mlx_lm.server resolves the request "model" string before looking up --adapter-path,
# so the CLI adapter is dropped (mlx-lm #1248). Pass the adapter resolved from the
# original alias ("default_model") so the loaded model keeps it.
export MLX_MODEL="$MLX_BASE_MODEL"
export MLX_ADAPTER="$ADAPTER"
export MLX_HOST="127.0.0.1"
export MLX_PORT="$VLLM_PORT"

LAUNCH=( "$PY" -c '
import os
import sys
import mlx_lm.server as server

_orig = server.ModelProvider.load

def load(self, model_path, adapter_path=None, draft_model_path=None):
    if adapter_path is None:
        adapter_path = self._adapter_map.get(model_path)
        if adapter_path is None:
            resolved = self._model_map.get(model_path, model_path)
            adapter_path = self._adapter_map.get(resolved)
    return _orig(self, model_path, adapter_path, draft_model_path)

server.ModelProvider.load = load
adapter = os.environ.get("MLX_ADAPTER") or None
sys.argv = [
    "mlx_lm.server",
    "--model", os.environ["MLX_MODEL"],
    "--host", os.environ["MLX_HOST"],
    "--port", os.environ["MLX_PORT"],
    *(["--adapter-path", adapter] if adapter else []),
]
server.main()
' )

if [[ ${1:-} == --fg ]]; then exec "${LAUNCH[@]}"; fi
nohup "${LAUNCH[@]}" > logs/mlx.log 2>&1 &
echo $! > "$PID_FILE"

echo -n "waiting for mlx_lm.server"
for _ in $(seq 300); do
  if curl -sf "http://127.0.0.1:$VLLM_PORT/v1/models" >/dev/null; then echo " ready"; exit 0; fi
  kill -0 "$(cat "$PID_FILE")" 2>/dev/null || { echo " crashed — see logs/mlx.log"; exit 1; }
  echo -n "."; sleep 2
done
echo " timeout — see logs/mlx.log"; exit 1
