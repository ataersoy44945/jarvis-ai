# Jarvis AI

Cross-platform personal AI assistant (Flutter + FastAPI).

## Stack

- **App:** Flutter (Windows, macOS, iOS, Android)
- **API:** FastAPI + SQLite + JWT auth + OpenAI

## Quick start

### 1) Backend

```bash
cd backend
python -m venv .venv

# Windows
.venv\Scripts\activate

# macOS / Linux
# source .venv/bin/activate

pip install -r requirements.txt
copy .env.example .env   # then set OPENAI_API_KEY
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check: http://127.0.0.1:8000/health

### 2) Flutter app

```bash
cd apps/jarvis_app
flutter pub get
flutter run -d windows
# flutter run -d macos
# flutter run -d chrome   # UI only; mic varies by browser
```

Override API URL when needed:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000
# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Physical phone (same Wi-Fi):
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

### 3) Use it

1. Register an account
2. Type a message or tap the mic
3. Jarvis replies on screen and speaks

## Project layout

```
jarvis-ai/
  backend/                 FastAPI service
  apps/jarvis_app/         Flutter client
  README.md
```

## API

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | no | Create user |
| POST | `/auth/login` | no | Login → JWT |
| GET | `/auth/me` | yes | Current user |
| POST | `/chat` | yes | Send message |
| GET | `/chat/conversations` | yes | List chats |
| GET | `/chat/conversations/{id}` | yes | Chat + messages |

## Notes

- Microphone / STT quality depends on OS speech services (especially desktop).
- Without `OPENAI_API_KEY`, the API returns a setup hint instead of crashing.
- v1 does **not** include device control or reminders.
