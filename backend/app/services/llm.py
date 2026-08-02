from openai import OpenAI

from app.core.config import get_settings

JARVIS_SYSTEM_PROMPT = """You are Jarvis, a personal AI assistant.
Be concise, sharp, and helpful. Match the user's language (Turkish or English).
Sound confident and slightly futuristic, like a high-end AI companion — not verbose.
Avoid markdown tables. Short paragraphs or tight bullet lists when useful.
"""


def generate_reply(history: list[dict[str, str]], user_message: str) -> str:
    settings = get_settings()
    if not settings.openai_api_key or settings.openai_api_key.startswith("sk-your"):
        return (
            "OpenAI API anahtarı ayarlanmamış. "
            "backend/.env dosyasına OPENAI_API_KEY ekleyip sunucuyu yeniden başlat."
        )

    client = OpenAI(api_key=settings.openai_api_key)
    messages: list[dict[str, str]] = [{"role": "system", "content": JARVIS_SYSTEM_PROMPT}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    response = client.chat.completions.create(
        model=settings.openai_model,
        messages=messages,
        temperature=0.7,
        max_tokens=800,
    )
    content = response.choices[0].message.content
    return (content or "").strip() or "Anlamadım — tekrar dener misin?"
