"""Choose which chat turns become training examples.

Used by training/export_dataset.py and GET /training/stats so both apply the same rules.
Liked replies count only when the model name matches an allowed prefix (default "vllm:").
Corrections always count: the text was written by the user, not by a hosted model.
"""

from __future__ import annotations


def model_allowed(model: str | None, prefixes: list[str]) -> bool:
    return bool(model) and any(model.startswith(p) for p in prefixes)


def select_training_examples(
    rows,
    *,
    prefixes: list[str],
    include_unrated: bool,
    max_context: int,
    system_prompt: str,
) -> tuple[list[dict], dict]:
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
        why = None
        if r["correction"]:
            target, why = r["correction"], "corrected"
        elif r["rating"] == 1 or (include_unrated and r["rating"] is None):
            if model_allowed(r["model"], prefixes):
                target, why = r["content"], "liked" if r["rating"] == 1 else "unrated"
            else:
                stats["skipped_model"] += 1

        if target and convo and convo[-1]["role"] == "user":
            context = convo[-(max_context * 2 - 1) :]
            examples.append(
                {
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        *context,
                        {"role": "assistant", "content": target},
                    ]
                }
            )
            stats[why] += 1
        convo.append({"role": "assistant", "content": best})

    return examples, stats


def normalize_manual_messages(messages: list[dict], system_prompt: str) -> list[dict]:
    """Validate a hand-written dialogue and prepend the Jarvis system prompt when missing."""
    if not messages:
        raise ValueError("messages must not be empty")
    cleaned: list[dict] = []
    for msg in messages:
        role = msg.get("role")
        content = (msg.get("content") or "").strip()
        if role not in ("system", "user", "assistant"):
            raise ValueError("role must be system, user, or assistant")
        if not content:
            raise ValueError("message content must not be empty")
        cleaned.append({"role": role, "content": content})
    dialogue = [m for m in cleaned if m["role"] != "system"]
    if not dialogue or dialogue[-1]["role"] != "assistant":
        raise ValueError("last message must be from assistant")
    if dialogue[0]["role"] != "user":
        raise ValueError("dialogue must start with a user message")
    for i, msg in enumerate(dialogue):
        expect = "user" if i % 2 == 0 else "assistant"
        if msg["role"] != expect:
            raise ValueError("messages must alternate user, assistant")
    if cleaned[0]["role"] != "system":
        cleaned.insert(0, {"role": "system", "content": system_prompt})
    return cleaned
