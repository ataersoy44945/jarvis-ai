from openai import OpenAI

from app.core.config import get_settings

JARVIS_SYSTEM_PROMPT = """You are Jarvis, a personal AI assistant.
Be concise, sharp, and helpful. Match the user's language (Turkish or English).
Sound confident and slightly futuristic, like a high-end AI companion — not verbose.
Avoid markdown tables. Short paragraphs or tight bullet lists when useful.
"""

GROQ_BASE_URL = "https://api.groq.com/openai/v1"
GROQ_DEFAULT_MODEL = "llama-3.3-70b-versatile"


def _is_missing_key(api_key: str) -> bool:
    return (
        not api_key
        or api_key.startswith("sk-your")
        or api_key in {"gsk_xxx", "changeme"}
    )


def _resolve_client(settings) -> tuple[OpenAI, str]:
    api_key = settings.openai_api_key.strip()
    base_url = (settings.openai_base_url or "").strip() or None
    model = settings.openai_model

    # Groq keys start with gsk_ — auto-wire OpenAI-compatible endpoint.
    if api_key.startswith("gsk_"):
        base_url = base_url or GROQ_BASE_URL
        if model.startswith("gpt-") or model == "gpt-4o-mini":
            model = GROQ_DEFAULT_MODEL

    kwargs: dict = {"api_key": api_key}
    if base_url:
        kwargs["base_url"] = base_url
    return OpenAI(**kwargs), model


def generate_reply(history: list[dict[str, str]], user_message: str) -> str:
    settings = get_settings()
    if _is_missing_key(settings.openai_api_key):
        return (
            "API anahtarı ayarlanmamış. "
            "Ücretsiz Groq için: console.groq.com/keys → key al, "
            "backend/.env içinde OPENAI_API_KEY=gsk_... yapıp sunucuyu yeniden başlat."
        )

    client, model = _resolve_client(settings)
    messages: list[dict[str, str]] = [{"role": "system", "content": JARVIS_SYSTEM_PROMPT}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    response = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=0.7,
        max_tokens=800,
    )
    content = response.choices[0].message.content
    return (content or "").strip() or "Anlamadım — tekrar dener misin?"
