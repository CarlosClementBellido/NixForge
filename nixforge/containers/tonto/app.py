import os, json, tempfile, subprocess, shutil
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re
from pathlib import Path

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

class AskBody(BaseModel):
    question: str
    system: str | None = None

def _ask_text(question: str, system: str | None = None) -> str:
    contents = f"[system]{system}[/system]\n{question}" if system else question
    return _vertex_generate_text(contents)

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
