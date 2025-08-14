import os, json
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
        # service account JSON suele traer 'project_id'
        return data.get("project_id")
    except Exception:
        return None

PROJECT  = os.getenv("GCP_PROJECT_ID") or _project_from_credentials()
LOCATION = os.getenv("GCP_LOCATION", "global")  # flash-lite => global
MODEL    = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")

if not PROJECT:
    raise RuntimeError("No se pudo determinar el proyecto. Define GCP_PROJECT_ID o pon 'project_id' en el JSON de credenciales.")

# ADC via GOOGLE_APPLICATION_CREDENTIALS:
client = genai.Client(vertexai=True, project=PROJECT, location=LOCATION)

app = FastAPI(title="tonto")

class AskBody(BaseModel):
    question: str
    system: str | None = None

@app.post("/ask")
async def ask(body: AskBody):
    try:
        contents = f"[system]{body.system}[/system]\n{body.question}" if body.system else body.question
        resp = client.models.generate_content(model=MODEL, contents=contents)
        return {"answer": resp.text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    try:
        r = client.models.generate_content(model=MODEL, contents="ping")
        return {"ok": True, "sample": (r.text or "")[:64], "project": PROJECT, "location": LOCATION, "model": MODEL}
    except Exception as e:
        return {"ok": False, "error": str(e)}
