import json
import urllib.error
import urllib.request


def call(method: str, path: str, data=None, token=None):
    req = urllib.request.Request(f"http://127.0.0.1:8000{path}", method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    body = None if data is None else json.dumps(data).encode()
    with urllib.request.urlopen(req, data=body) as res:
        return json.load(res)


print("health", call("GET", "/health"))
try:
    reg = call(
        "POST",
        "/auth/register",
        {"email": "ata@jarvis.test", "password": "secret12", "name": "Ata"},
    )
    print("register", reg["email"], bool(reg.get("access_token")))
except urllib.error.HTTPError as e:
    print("register note", e.read().decode())
    reg = call(
        "POST",
        "/auth/login",
        {"email": "ata@jarvis.test", "password": "secret12"},
    )
    print("login", reg["email"])

token = reg["access_token"]
chat = call(
    "POST",
    "/chat",
    {"message": "Merhaba Jarvis, kisa cevap ver"},
    token=token,
)
print("chat", chat["conversation_id"], chat["reply"][:160])
hist = call("GET", f"/chat/conversations/{chat['conversation_id']}", token=token)
print("messages", len(hist["messages"]))
