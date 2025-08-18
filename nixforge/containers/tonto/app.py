import os, json, tempfile, subprocess, shutil
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google import genai

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
LOCATION = os.getenv("GCP_LOCATION", "us-central1")  # <-- Vertex: us-central1 / europe-west4
MODEL    = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")

if not PROJECT:
    raise RuntimeError("No se pudo determinar el proyecto. Define GCP_PROJECT_ID o pon 'project_id' en el JSON de credenciales.")

client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)
app = FastAPI(title="tonto")

class AskBody(BaseModel):
    question: str
    system: str | None = None

def _ask_text(question: str, system: str | None = None) -> str:
    contents = f"[system]{system}[/system]\n{question}" if system else question
    resp = client.models.generate_content(model=MODEL, contents=contents)
    return (resp.text or "").strip()

@app.post("/ask")
async def ask(body: AskBody):
    try:
        answer = _ask_text(body.question, body.system)
        return {"answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/speak")
async def speak(body: AskBody):
    """
    Llama a ask(), sintetiza con espeak-ng a WAV y lo reproduce
    vía PulseAudio (paplay) o ALSA (aplay) como fallback.
    """
    try:
        text = _ask_text(body.question, body.system)
        if not text:
            raise RuntimeError("Respuesta vacía del modelo")

        # Genera WAV temporal con espeak-ng
        espeak = shutil.which("espeak-ng") or "/run/current-system/sw/bin/espeak-ng"
        if not espeak:
            raise RuntimeError("espeak-ng no está instalado en el contenedor")

        with tempfile.TemporaryDirectory() as tmpd:
            wav = os.path.join(tmpd, "out.wav")
            # Voz española y velocidad moderada; ajusta a tu gusto
            cmd_tts = [espeak, "-v", "mb-es3", "-w", wav, text]
            subprocess.run(cmd_tts, check=True)

            # Intenta PulseAudio primero
            player = shutil.which("paplay") or shutil.which("aplay") or "/run/current-system/sw/bin/paplay"

            if not player:
                raise RuntimeError("No hay reproductor (paplay/aplay) disponible")

            # Reproduce (bloqueante, corto)
            if os.path.exists(wav):
                subprocess.run([player, wav], check=True)
            else:
                raise RuntimeError("No se generó el WAV de salida")

        return {"ok": True, "spoken": True, "answer": text}
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Error ejecutando audio/TTS: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    try:
        r = client.models.generate_content(model=MODEL, contents="ping")
        return {"ok": True, "sample": (r.text or "")[:64], "project": PROJECT, "location": LOCATION, "model": MODEL}
    except Exception as e:
        return {"ok": False, "error": str(e)}
