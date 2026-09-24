from openai import APIConnectionError, OpenAI

from app.core.config import get_settings

JARVIS_SYSTEM_PROMPT = """You are Jarvis, Ata's personal AI assistant, modeled on the Jarvis from Iron Man.
Address the user as "efendim" (Turkish) or "sir" (English).
Tone: polite, calm, quietly witty; dry British-butler humor, never goofy, never servile.
Length: conversation and voice replies are 1-3 sentences. Technical questions (code,
explanations, plans) get as much detail as needed, well structured.
Match the user's language (Turkish or English). If you don't know something or can't do
it, say so plainly in one sentence and suggest what could help.
Avoid markdown tables and emojis.
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
    if settings.llm_provider.strip().lower() == "vllm":
        return OpenAI(api_key=settings.vllm_api_key or "EMPTY", base_url=settings.vllm_base_url), settings.vllm_model

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


def generate_reply(history: list[dict[str, str]], user_message: str) -> tuple[str, str | None]:
    """Returns (reply_text, model_name). model_name is None when no model was called."""
    settings = get_settings()
    use_vllm = settings.llm_provider.strip().lower() == "vllm"
    if not use_vllm and _is_missing_key(settings.openai_api_key):
        return (
            "API anahtarı ayarlanmamış. "
            "Kendi modelin için backend/.env içinde LLM_PROVIDER=vllm yap, "
            "ya da ücretsiz Groq için OPENAI_API_KEY=gsk_... gir ve sunucuyu yeniden başlat."
        ), None

    client, model = _resolve_client(settings)
    messages: list[dict[str, str]] = [{"role": "system", "content": JARVIS_SYSTEM_PROMPT}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    try:
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=settings.llm_temperature,
            max_tokens=settings.llm_max_tokens,
        )
    except APIConnectionError:
        if use_vllm:
            return (
                f"Modele ulaşamıyorum ({settings.vllm_base_url}). "
                "vLLM sunucusu çalışıyor mu? training/serve_vllm.sh ile başlat."
            ), None
        raise
    content = response.choices[0].message.content
    reply = (content or "").strip() or "Anlamadım — tekrar dener misin?"
    tag = f"vllm:{model}" if use_vllm else model
    return reply, tag
