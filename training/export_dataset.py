"""Build a training set for Jarvis from the backend's SQLite DB + your hand-written examples.

Output: JSONL, one example per line:
    {"messages": [{"role": "system", ...}, {"role": "user", ...}, ..., {"role": "assistant", ...}]}
Only the LAST assistant message of each example is trained on; earlier turns are context.

What becomes a training target:
  * a reply you corrected (the correction is used, not the original)   -> always
  * a reply you gave thumbs-up to                                       -> only if its model is allowed
  * thumbs-down without correction, or unrated                          -> never
    (unless --include-unrated, and still only for allowed models)

Why "allowed models"? The terms of OpenAI, Anthropic and most hosted APIs forbid using
their outputs to train another model. By default only replies written by your own vLLM
model (model name starts with "vllm:") count. Your own corrections are always yours.

Usage:
    python export_dataset.py --db ../backend/jarvis.db --out data/train.jsonl
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "backend"))
try:
    from app.services.llm import JARVIS_SYSTEM_PROMPT  # keep train/serve prompts identical
except Exception:  # backend deps not installed on the GPU box — fall back to a copy
    JARVIS_SYSTEM_PROMPT = (HERE / "system_prompt.txt").read_text(encoding="utf-8")


def model_allowed(model: str | None, prefixes: list[str]) -> bool:
    return bool(model) and any(model.startswith(p) for p in prefixes)


def from_db(db_path: Path, prefixes: list[str], include_unrated: bool, max_context: int) -> list[dict]:
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    cols = {r["name"] for r in con.execute("PRAGMA table_info(messages)")}
    has_fb = con.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='feedback'").fetchone()
    if "model" not in cols or not has_fb:
        sys.exit("DB is from an old backend version — start the new backend once so it migrates.")

    rows = con.execute(
        """
        SELECT m.id, m.conversation_id, m.role, m.content, m.model,
               f.rating, f.correction
        FROM messages m
        LEFT JOIN feedback f ON f.message_id = m.id
        WHERE m.role IN ('user', 'assistant')
        ORDER BY m.conversation_id, m.id
        """
    ).fetchall()

    examples: list[dict] = []
    stats = {"corrected": 0, "liked": 0, "unrated": 0, "skipped_model": 0}
    convo: list[dict] = []
    current = None
    for r in rows:
        if r["conversation_id"] != current:
            current, convo = r["conversation_id"], []

        if r["role"] == "user":
            convo.append({"role": "user", "content": r["content"]})
            continue

        # assistant turn
        best = r["correction"] or r["content"]  # corrected text wins in the context too
        target = None
        if r["correction"]:
            target, why = r["correction"], "corrected"
        elif r["rating"] == 1 or (include_unrated and r["rating"] is None):
            if model_allowed(r["model"], prefixes):
                target, why = r["content"], "liked" if r["rating"] == 1 else "unrated"
            else:
                stats["skipped_model"] += 1

        if target and convo and convo[-1]["role"] == "user":
            context = convo[-(max_context * 2 - 1):]
            examples.append(
                {"messages": [{"role": "system", "content": JARVIS_SYSTEM_PROMPT}, *context,
                              {"role": "assistant", "content": target}]}
            )
            stats[why] += 1
        convo.append({"role": "assistant", "content": best})

    con.close()
    print(f"[db] {db_path}: {stats}")
    return examples


def from_manual(folder: Path) -> list[dict]:
    """Hand-written examples: data/manual/*.jsonl, same format. System prompt is added if missing."""
    out: list[dict] = []
    for f in sorted(folder.glob("*.jsonl")):
        if f.name.startswith("_"):  # _template.jsonl etc. are ignored
            continue
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip():
                continue
            ex = json.loads(line)
            msgs = ex["messages"]
            if msgs[-1]["role"] != "assistant":
                sys.exit(f"{f}:{n} — last message must be from assistant")
            if msgs[0]["role"] != "system":
                msgs.insert(0, {"role": "system", "content": JARVIS_SYSTEM_PROMPT})
            out.append({"messages": msgs})
    print(f"[manual] {folder}: {len(out)} examples")
    return out


def dedupe(examples: list[dict]) -> list[dict]:
    seen, out = set(), []
    for ex in examples:
        h = hashlib.sha1(json.dumps(ex["messages"][1:], ensure_ascii=False, sort_keys=True).encode()).hexdigest()
        if h not in seen:
            seen.add(h)
            out.append(ex)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", type=Path, default=HERE.parent / "backend" / "jarvis.db")
    ap.add_argument("--manual", type=Path, default=HERE / "data" / "manual")
    ap.add_argument("--out", type=Path, default=HERE / "data" / "train.jsonl")
    ap.add_argument("--eval-out", type=Path, default=HERE / "data" / "eval.jsonl")
    ap.add_argument("--eval-ratio", type=float, default=0.05)
    ap.add_argument("--allow-model", action="append", default=["vllm:"],
                    help="model-name prefix whose liked replies may be trained on (repeatable)")
    ap.add_argument("--include-unrated", action="store_true")
    ap.add_argument("--max-context-turns", type=int, default=6)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    examples: list[dict] = []
    if args.db.exists():
        examples += from_db(args.db, args.allow_model, args.include_unrated, args.max_context_turns)
    else:
        print(f"[db] {args.db} not found — skipping")
    if args.manual.exists():
        examples += from_manual(args.manual)

    examples = dedupe(examples)
    random.Random(args.seed).shuffle(examples)
    n_eval = int(len(examples) * args.eval_ratio) if len(examples) >= 40 else 0
    eval_set, train_set = examples[:n_eval], examples[n_eval:]

    args.out.parent.mkdir(parents=True, exist_ok=True)
    for path, data in ((args.out, train_set), (args.eval_out, eval_set)):
        with path.open("w", encoding="utf-8") as fh:
            for ex in data:
                fh.write(json.dumps(ex, ensure_ascii=False) + "\n")
    print(f"[out] train={len(train_set)} -> {args.out} | eval={len(eval_set)} -> {args.eval_out}")


if __name__ == "__main__":
    main()
