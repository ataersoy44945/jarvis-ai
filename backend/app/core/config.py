from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8-sig",
        extra="ignore",
    )

    # "openai" (OpenAI / Groq / any hosted OpenAI-compatible API) or "vllm" (own model)
    llm_provider: str = "openai"

    openai_api_key: str = ""
    # Leave empty for OpenAI. For Groq free tier use: https://api.groq.com/openai/v1
    openai_base_url: str = ""
    openai_model: str = "gpt-4o-mini"

    # Self-hosted vLLM (OpenAI-compatible). Port 8001 so it doesn't clash with this API on 8000.
    vllm_base_url: str = "http://127.0.0.1:8001/v1"
    # Name passed to vLLM: base model id, or the LoRA adapter name from --lora-modules (e.g. "jarvis")
    vllm_model: str = "jarvis"
    vllm_api_key: str = "EMPTY"
    llm_temperature: float = 0.7
    llm_max_tokens: int = 800
    jwt_secret: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"
    database_url: str = "sqlite:///./jarvis.db"

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
