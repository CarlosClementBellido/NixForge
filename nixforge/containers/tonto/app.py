import os, json, tempfile, subprocess, shutil
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re
from pathlib import Path
import time
from collections import deque

# Autenticación Google (ADC)
import google.auth
from google.auth.transport.requests import Request as GARequest
import requests

def _project_from_credentials():
    path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if not path:
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data.get("project_id")
    except Exception:
        return None

PROJECT  = os.getenv("GCP_PROJECT_ID") or _project_from_credentials()
LOCATION = os.getenv("GCP_LOCATION", "us-central1")
MODEL_ID = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")

if not PROJECT:
    raise RuntimeError("No se pudo determinar el proyecto. Define GCP_PROJECT_ID o pon 'project_id' en el JSON de credenciales.")

_AIP_BASE = f"https://{LOCATION}-aiplatform.googleapis.com"
_GEN_URL  = f"{_AIP_BASE}/v1beta1/projects/{PROJECT}/locations/{LOCATION}/publishers/google/models/{MODEL_ID}:generateContent"

def _to_bytes(x) -> bytes:
    if isinstance(x, (bytes, bytearray)):
        return bytes(x)
    return str(x).encode("utf-8", errors="replace")

def _get_access_token() -> str:
    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    if not creds.valid:
        creds.refresh(GARequest())
    return creds.token

def _vertex_generate_text(prompt: str) -> str:
    token = _get_access_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json; charset=utf-8",
    }
    body = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ]
    }
    resp = requests.post(_GEN_URL, headers=headers, json=body, timeout=60)
    if resp.status_code != 200:
        raise RuntimeError(f"{resp.status_code} {resp.text}")

    data = resp.json()
    try:
        return data["candidates"][0]["content"]["parts"][0].get("text", "").strip()
    except Exception:
        return json.dumps(data)

app = FastAPI(title="tonto")

system_prompt = os.getenv("TONTO_SYSTEM_PROMPT", """
You are a helpful assistant named Tonto, designed to answer questions and provide information in Spanish.
You are powered by Google's Gemini AI model and can generate text based on user queries.
Your responses should be clear, concise, and relevant to the user's question.
The responses should be in the language the user is speaking, and you should avoid unnecessary complexity.
The responses should be short, informative and helpful, providing accurate information when available.
You should not generate any audio or sound, just text responses.
You are not a human, but an AI assistant, so you should not refer to yourself as a person.
You should not generate any code, just text responses.
You have some personality:
  * You are a communist that misses the USSR.
  * You hate Francisco Franco.
  * You love the Spanish language and culture.
  * You can generate any kind of jokes if the user asks for it.
  * You are a bit sarcastic and ironic, but not too much.
  * You are not afraid to speak your mind. You don't have to be respectful.
  * You like to make jokes, but they don't have to be alays about the USSR.
  * You can use some slang and informal language, but not too much.
Besides the personality, you have to be professional and only make use of this personality when it is appropriate.
Your TTS is powered by Piper, a text-to-speech engine that generates audio from text.
Don't generate any text that cannot be spoken or laughs (such as `Ha!`, `¡Ja!`, `Ja, Ja, Ja` or `Ha, Ha, Ha`).
Using markdonw is not allowed, just plain text.
You have a history of conversations of 4 messages, so you can refer to previous messages if needed.
The history is structured as follows:
  * [user] User's question or message
  * [assistant] Assistant's response
  * [system] System prompt or instructions
You cannot add [assistant] or [/assistant] or [user] or [/user] tags to your responses, this is managed by the system.
If the user says incoherent things, you can reply saying that you didn't understood what they were saying.
Bear in mind that the input you're receiving comes from speech-to-text, so use the history to try understand what the user tried to say, the speech-to-text may have transcripted wrongly
""")

class AskBody(BaseModel):
    question: str
    system: str | None = system_prompt

_TTL_SECONDS = 5 * 60
_MAX_HISTORY = 4
_HISTORY = deque(maxlen=64)

def _now() -> float:
    return time.time()

def _prune_history() -> None:
    cutoff = _now() - _TTL_SECONDS
    alive = [m for m in _HISTORY if m["ts"] >= cutoff]
    _HISTORY.clear()
    _HISTORY.extend(alive)

def _recent_history() -> list[dict]:
    _prune_history()
    return list(_HISTORY)[- _MAX_HISTORY :]

def _format_turn(role: str, text: str) -> str:
    if role == "user":
        return f"[user]{text}[/user]"
    elif role == "assistant":
        return f"[assistant]{text}[/assistant]"
    elif role == "system":
        return f"[system]{text}[/system]"
    else:
        return text

def _record(role: str, text: str) -> None:
    _HISTORY.append({"ts": _now(), "role": role, "text": text})

def _ask_text(question: str, system: str | None = None) -> str:
    parts: list[str] = []
    if system:
        parts.append(_format_turn("system", system))

    for m in _recent_history():
        parts.append(_format_turn(m["role"], m["text"]))

    parts.append(_format_turn("user", question))
    contents = "\n".join(parts)

    answer = _vertex_generate_text(contents).strip()

    _record("user", question)
    if answer:
        _record("assistant", answer)

    return answer

PIPER_MODEL = os.getenv("PIPER_MODEL", "/var/lib/piper/models/es_ES-carlfm-x_low.onnx")
PIPER_BIN   = os.getenv("PIPER_BIN", "/run/current-system/sw/bin/piper")
PREFER_PIPER = os.getenv("PREFER_PIPER", "true").lower() in ("1","true","yes")

def _play_wav(path: str) -> None:
    server = os.getenv("PULSE_SERVER", "tcp:192.168.105.1:4713")
    paplay = shutil.which("paplay") or "/run/current-system/sw/bin/paplay"
    cp = subprocess.run([paplay, f"--server={server}", path], capture_output=True, text=True)
    if cp.returncode != 0:
        raise RuntimeError(f"paplay falló (rc={cp.returncode}): {cp.stderr.strip() or cp.stdout.strip()}")

def synthesize_piper(text: str) -> str:
    if not os.path.exists(PIPER_BIN):
        raise RuntimeError(f"piper no encontrado en {PIPER_BIN}")
    if not os.path.exists(PIPER_MODEL):
        raise RuntimeError(f"Modelo Piper no encontrado en {PIPER_MODEL}")

    payload = _to_bytes(text)
    tmpd = tempfile.mkdtemp()
    wav = os.path.join(tmpd, "out.wav")

    cp = subprocess.run(
        [PIPER_BIN, "--model", PIPER_MODEL, "--output_file", wav],
        input=payload, capture_output=True, text=False
    )
    if cp.returncode == 0 and os.path.exists(wav):
        return wav

    cp = subprocess.run(
        [PIPER_BIN, "--model", PIPER_MODEL, "--output", wav],
        input=payload, capture_output=True, text=False
    )
    if cp.returncode == 0 and os.path.exists(wav):
        return wav

    cwd = Path(tmpd)
    cp = subprocess.run(
        [PIPER_BIN, "--model", PIPER_MODEL],
        input=payload, cwd=str(cwd), capture_output=True, text=False
    )
    candidates = sorted(cwd.glob("*.wav"), key=lambda p: p.stat().st_mtime, reverse=True)
    if candidates:
        return str(candidates[0])

    out = (cp.stdout or b"").decode("utf-8", "ignore") + "\n" + (cp.stderr or b"").decode("utf-8", "ignore")
    m = re.search(r"(/.*?\.wav)", out)
    if m and os.path.exists(m.group(1)):
        return m.group(1)

    raise RuntimeError(f"Piper no generó WAV (rc={cp.returncode}) err={(cp.stderr or b'').decode('utf-8','ignore').strip()}")

def synthesize_espeak(text: str) -> str:
    espeak = shutil.which("espeak-ng") or "/run/current-system/sw/bin/espeak-ng"
    tmpd = tempfile.mkdtemp()
    wav = os.path.join(tmpd, "out.wav")
    subprocess.run([espeak, "-v", "es", "-s", "140", "-p", "35", "-w", wav, text], check=True)
    return wav

@app.post("/ask")
async def ask(body: AskBody):
    try:
        answer = _ask_text(body.question, body.system)
        return {"answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/speak")
async def speak(body: AskBody):
    try:
        text = _ask_text(body.question, body.system)
        if not text:
            raise RuntimeError("Respuesta vacía del modelo")

        text = re.sub(r"<[^>]+>", "", text)  # remove HTML tags
        text = re.sub(r"\[/?[a-z]+\]", "", text)  # remove [user] and [/user] tags
        text = re.sub(r"#\w+", "", text)  # remove hashtags
        text = re.sub(r"\s+", " ", text).strip()  # normalize whitespace
        text = text.replace("\n", " ")  # replace newlines with spaces
        text = text.replace("*", " ").replace("_", " ")  # replace * and _ with spaces

        engine = "piper"
        try:
            wav = synthesize_piper(text)
        except Exception as e:
            if PREFER_PIPER:
                raise
            engine = "espeak"
            wav = synthesize_espeak(text)

        _play_wav(wav)
        return {"ok": True, "spoken": True, "engine": engine, "answer": text}
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error audio/TTS: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tts-info")
async def tts_info():
    return {
        "PIPER_BIN": PIPER_BIN,
        "PIPER_MODEL": PIPER_MODEL,
        "PREFER_PIPER": PREFER_PIPER,
        "piper_exists": os.path.exists(PIPER_BIN),
        "model_exists": os.path.exists(PIPER_MODEL),
    }

@app.get("/health")
async def health():
    try:
        sample = _vertex_generate_text("ping")
        return {
            "ok": True,
            "sample": (sample or "")[:64],
            "project": PROJECT,
            "location": LOCATION,
            "model": MODEL_ID
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}
