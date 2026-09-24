# Jarvis'i kendi modelinle çalıştırma (vLLM + QLoRA)

Jarvis'in beyni artık dışarıdaki bir API yerine **senin sunucunda çalışan açık bir model** olabilir.
Döngü şöyle:

```
Jarvis'le konuş ─► 👍 / 👎 / ✏️ düzelt ─► export_dataset.py ─► train_lora.py ─► vLLM yeni adapter'la açılır
        ▲                                                                              │
        └──────────────────────────────────────────────────────────────────────────────┘
                                   pipeline.sh bu döngünün tamamını yapar (cron'a koyabilirsin)
```

## Gereksinimler

- Linux + NVIDIA GPU. 7B model için **24 GB VRAM** (RTX 3090/4090, A10, L4). 12–16 GB için `BASE_MODEL=Qwen/Qwen2.5-3B-Instruct`.
- Windows laptop'ta vLLM çalışmaz. Planladığın kiralık GPU'lu VPS bunun için doğru yer.
- Varsayılan taban model: **Qwen2.5-7B-Instruct** (Apache-2.0, Türkçesi iyi). `jarvis.env` içinden değişir.

## 1) Kurulum (GPU sunucusunda)

```bash
cd training
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pip install vllm            # ayrı bir venv'e kurmak daha temiz, vLLM kendi torch sürümünü ister
```

## 2) Modeli servis et

```bash
./serve_vllm.sh             # :8001/v1 adresinde OpenAI uyumlu API açılır
```

Henüz eğitim yoksa taban model `jarvis` adıyla servis edilir. Jarvis ilk günden kendi modelinle çalışır.

## 3) Backend'i vLLM'e bağla

`backend/.env`:

```
LLM_PROVIDER=vllm
VLLM_BASE_URL=http://127.0.0.1:8001/v1     # vLLM başka makinedeyse o makinenin IP'si
VLLM_MODEL=jarvis
```

Backend'i yeniden başlat. API anahtarı gerekmez.

## 4) Veri topla

Uygulamada her Jarvis cevabının altında üç buton var:

| Buton | Anlamı | Eğitimde |
|---|---|---|
| 👍 | İyi cevap | Kullanılır (cevap senin vLLM modelinden geldiyse) |
| 👎 | Kötü cevap | Kullanılmaz |
| ✏️ | "Şöyle demeliydin" | **Senin yazdığın metin** eğitilir. En değerli sinyal bu |

Elle örnek de yazabilirsin: `data/manual/` içine `.jsonl` dosyası koy (format için `_template.jsonl`'e bak; `_` ile başlayan dosyalar atlanır).

## 5) Eğit ve devreye al

```bash
./pipeline.sh               # yeterli yeni veri yoksa kendiliğinden atlar
./pipeline.sh --force       # yine de eğit
```

Pipeline sırasıyla şunları yapar: veriyi dışa aktarır, vLLM'i durdurup GPU'yu boşaltır, `adapters/vNNN` eğitir,
`adapters/current`'i yeni sürüme çevirir, vLLM'i açar ve test mesajı yollar. Test başarısız olursa **önceki sürüme geri döner**.

Otomatik çalıştırmak için (her gece 03:00):

```bash
crontab -e
0 3 * * * /yol/jarvis-ai/training/pipeline.sh
```

Loglar: `logs/pipeline.log`, `logs/vllm.log`.

## Önemli: hangi veriyle eğitebilirsin?

OpenAI, Anthropic (Claude) ve çoğu hosted API'nin kullanım şartları, **çıktılarını başka bir model eğitmek için kullanmayı yasaklar**.
Bu yüzden `export_dataset.py` varsayılan olarak şu verileri kullanır:

- senin ✏️ ile yazdığın düzeltmeleri,
- `data/manual/` içindeki kendi örneklerini,
- sadece **senin vLLM modelinin** (`model` alanı `vllm:` ile başlayan) 👍 aldığı cevapları.

Groq/OpenAI'dan gelen eski cevaplar eğitime girmez (`--allow-model` ile değiştirilebilir, ama şartlarını kontrol et).
Hugging Face'teki açık lisanslı Türkçe instruction veri setlerini de `data/manual/`'a dönüştürüp ekleyebilirsin. Her setin lisansına bak.

## Ne kadar veri lazım?

- **~50–200 iyi örnek:** Jarvis'in üslubu, kişiliği ve cevap uzunluğu belirgin şekilde oturur.
- **500+ örnek:** kendi alanına özgü bilgiler ve kalıplar oturmaya başlar.
- Fine-tune **yeni bilgi öğretmekte zayıftır**. Güncel bilgi, hatırlatıcı veya dosya gibi şeyler için ileride RAG/araç çağırma eklemek daha doğru.

## Mac'te (MLX) eğitim

Bu Mac (Apple Silicon, 8 GB RAM) vLLM çalıştıramaz. Aynı döngünün MLX hali `TRAIN_BACKEND=mlx` ile durur; NVIDIA dosyaları (`train_lora.py`, `serve_vllm.sh`, `requirements.txt`) yerinde kalır.

```bash
cd training
python3 -m venv .venv-mlx && source .venv-mlx/bin/activate
pip install -r requirements-mlx.txt
```

`jarvis.env`:

```
TRAIN_BACKEND=mlx
MLX_BASE_MODEL=mlx-community/Qwen2.5-1.5B-Instruct-4bit
MLX_SERVED_MODEL=default_model
```

8 GB için eğitim ayarı sabittir: batch 1, gradient checkpointing, sıra uzunluğu 1024, LoRA yalnızca son 8 katmanda. `./pipeline.sh --force` veriyi dışa aktarır, `train_mlx.sh` ile `adapters/vNNN` üretir, `serve_mlx.sh` modeli `127.0.0.1:8001` üzerinde açar ve duman testini yapar. Test düşerse önceki `adapters/current` geri gelir.

`mlx_lm.server` istekteki `model` alanını bir model yolu sayar. CLI ile açılan modeli ve adapter'ı seçen tek hazır ad `default_model`'dir. Başka bir ad (örneğin `jarvis`) ayrı bir model yüklemeye çalışır ve adapter'ı kullanmaz. Bu yüzden `backend/.env` şöyle olmalı:

```
LLM_PROVIDER=vllm
VLLM_BASE_URL=http://127.0.0.1:8001/v1
VLLM_MODEL=default_model
```

Sunucu, `--adapter-path` değerini takma ad çözüldükten sonra aradığı için CLI adapter'ını düşürür (mlx-lm #1248). `serve_mlx.sh` adapter'ı takma ad üzerinden geri bağlar. Eğitim verisi filtresi değişmez: 👍 yalnızca `vllm:` ile kayıtlı kendi model cevaplarında, ✏️ her zaman senin metnindir.

Loglar: `logs/pipeline.log`, `logs/mlx.log`.

## Dosyalar

| Dosya | İş |
|---|---|
| `jarvis.env` | Taban model, port, eşikler |
| `export_dataset.py` | SQLite + manuel örnekler → `data/train.jsonl`, `data/eval.jsonl` |
| `train_lora.py` | QLoRA (4-bit, NVIDIA) eğitim → `adapters/vNNN` |
| `train_mlx.sh` | MLX LoRA (Apple Silicon) eğitim → `adapters/vNNN` |
| `serve_vllm.sh` | vLLM'i güncel adapter ile başlatır/durdurur |
| `serve_mlx.sh` | mlx_lm.server'ı güncel adapter ile başlatır/durdurur |
| `requirements-mlx.txt` | MLX venv bağımlılıkları (`.venv-mlx`) |
| `pipeline.sh` | Hepsini sırayla, güvenli şekilde çalıştırır |
| `system_prompt.txt` | Backend kurulu değilse kullanılan sistem prompt'u kopyası |
