import os
import time
import shlex
import logging
import subprocess
from typing import Optional, List

LOG = logging.getLogger("hotword")
logging.basicConfig(level=logging.INFO, format="%(message)s")

# ---------- Config ----------
WAKE_SENSITIVITY   = float(os.getenv("WAKE_SENSITIVITY", "0.55"))
HOTWORDS           = [w.strip() for w in os.getenv("HOTWORDS", "tonto,oye tonto,ok tonto").split(",") if w.strip()]

VAD_AGGRESSIVENESS = int(os.getenv("VAD_AGGRESSIVENESS", "2"))
SILENCE_TIMEOUT    = float(os.getenv("SILENCE_TIMEOUT", "1.0"))
MAX_LISTEN_SECONDS = float(os.getenv("MAX_LISTEN_SECONDS", "7"))

COOLDOWN_AFTER_TRIGGER = float(os.getenv("COOLDOWN_AFTER_TRIGGER", "2"))
COOLDOWN_AFTER_EMPTY   = float(os.getenv("COOLDOWN_AFTER_EMPTY", "2"))

ASR_MODEL    = os.getenv("ASR_MODEL", "tiny")
ASR_LANGUAGE = os.getenv("ASR_LANGUAGE", "es")
HF_HOME      = os.getenv("HF_HOME", "/var/lib/tonto/models")

# OWW 0.4.x (tflite, modelos embebidos en la wheel)
OWW_ALLOW    = [n.strip() for n in os.getenv("OWW_ALLOW","").split(",") if n.strip()]

# Faster-Whisper aceleración (si no hay CUDA, hacemos fallback automático)
FW_DEVICE       = os.getenv("FW_DEVICE", "cpu")           # "cuda" o "cpu"
FW_COMPUTE_TYPE = os.getenv("FW_COMPUTE_TYPE", "int8")    # en cuda: "int8_float16" suele ir bien

TONTO_URL    = os.getenv("TONTO_URL", "http://127.0.0.1:8088/speak")
TONTO_FIELD  = os.getenv("TONTO_FIELD", "question")       # o "text" según tu API

# ---------- Lazy imports / globals ----------
oww_model = None
vad = None
asr = None

def _parec_cmd() -> List[str]:
    return ["/run/current-system/sw/bin/parec", "--latency-msec=20", "--format=s16le", "--rate=16000", "--channels=1"]

def _capture_pcm(seconds: float) -> bytes:
    cmd = _parec_cmd()
    LOG.info("[hotword] Iniciando captura de audio: %s", " ".join(shlex.quote(c) for c in cmd))
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        data = p.stdout.read(int(16000 * 2 * seconds))
    finally:
        p.kill()
        p.wait()
    return data

def _beep():
    """Pitido corto 1kHz ~80ms por PulseAudio (paplay) o ALSA (aplay)."""
    try:
        import numpy as np, soundfile as sf
        from io import BytesIO
        sr = 16000
        dur = 0.08
        t = np.arange(int(sr * dur)) / sr
        wave = (0.2 * np.sin(2 * np.pi * 1000 * t)).astype("float32")
        bio = BytesIO()
        sf.write(bio, wave, sr, format="WAV", subtype="PCM_16")
        data = bio.getvalue()
        for cmd in (["/run/current-system/sw/bin/paplay", "-"],
                    ["/run/current-system/sw/bin/aplay", "-q", "-"]):
            try:
                p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                p.stdin.write(data)
                p.stdin.close()
                p.wait(timeout=2)
                return
            except Exception:
                continue
    except Exception as e:
        LOG.info("[hotword] beep falló: %r", e)

# ---------- OWW ----------
def _init_oww():
    global oww_model
    try:
        # OWW 0.4.x: Model() sin args => tflite y modelos embebidos
        from openwakeword.model import Model
        oww_model = Model()
        LOG.info("[hotword] OWW listo (0.4.x/TFLite, modelos embebidos)")
    except Exception as e:
        oww_model = None
        LOG.info("[hotword] OWW no disponible: %r", e)

# ---------- VAD ----------
def _init_vad():
    global vad
    try:
        import webrtcvad
        v = webrtcvad.Vad()
        v.set_mode(VAD_AGGRESSIVENESS)
        vad = v
        LOG.info("[hotword] VAD listo (webrtcvad, modo %d)", VAD_AGGRESSIVENESS)
    except Exception as e:
        vad = None
        LOG.info("[hotword] VAD no disponible (webrtcvad): %s", e)

def _apply_vad(pcm: bytes) -> bytes:
    if not vad:
        return pcm
    frame_ms = 30
    sr = 16000
    frame_len = int(sr * 2 * frame_ms / 1000)
    out = bytearray()
    for i in range(0, len(pcm), frame_len):
        chunk = pcm[i:i+frame_len]
        if len(chunk) < frame_len:
            break
        if vad.is_speech(chunk, sr):
            out += chunk
    # log informativo
    try:
        removed = max(0.0, (len(pcm) - len(out)) / (sr * 2))
        if removed > 0:
            LOG.info("VAD filter removed %02d:%05.2f of audio", int(removed // 60), removed % 60)
    except Exception:
        pass
    return bytes(out)

# ---------- ASR ----------
def _init_asr():
    global asr
    try:
        from faster_whisper import WhisperModel
        device = FW_DEVICE
        compute_type = FW_COMPUTE_TYPE
        try:
            asr = WhisperModel(ASR_MODEL, device=device, compute_type=compute_type, download_root=HF_HOME)
        except Exception as e:
            # Si falla CUDA, probamos CPU automáticamente
            if "CUDA" in repr(e) or "no CUDA-capable device" in repr(e):
                LOG.info("[hotword] CUDA no disponible, usando CPU…")
                asr = WhisperModel(ASR_MODEL, device="cpu", compute_type="int8", download_root=HF_HOME)
            else:
                raise
        LOG.info("[hotword] ASR listo (faster-whisper, device=%s)", device if asr else "cpu")
    except Exception as e:
        asr = None
        LOG.info("[hotword] ASR no disponible (faster-whisper): %s", e)

def transcribe(pcm: bytes) -> str:
    if not asr:
        return ""
    from io import BytesIO
    import soundfile as sf
    import numpy as np
    arr = (np.frombuffer(pcm, dtype="<i2").astype("float32") / 32768.0)
    bio = BytesIO(); sf.write(bio, arr, 16000, subtype="PCM_16", format="WAV"); bio.seek(0)
    segments, _ = asr.transcribe(
        bio,
        language=ASR_LANGUAGE,
        beam_size=1,
        best_of=1,
        vad_filter=False,                  # ya aplicamos nuestro VAD
        condition_on_previous_text=False,  # más robusto para frases sueltas
    )
    return "".join(seg.text for seg in segments).strip()

def _speak_with_tonto(text: str):
    import requests
    try:
        payload = {TONTO_FIELD: text}
        r = requests.post(TONTO_URL, json=payload, timeout=30)
        LOG.info("[hotword] Tonto habló: %s", r.json())
    except Exception as e:
        LOG.info("[hotword] fallo al llamar a /speak: %r", e)

# ---------- Main loop ----------
def main():
    global oww_model, vad, asr   # <- evita UnboundLocalError
    _init_oww()
    _init_vad()
    _init_asr()

    told_fallback = False

    while True:
        try:
            triggered = False

            # Intento con OWW si está disponible
            if oww_model is not None:
                pcm = _capture_pcm(0.8)
                if pcm:
                    import numpy as np
                    f32 = (np.frombuffer(pcm, dtype="<i2").astype("float32") / 32768.0)
                    scores = oww_model.predict(f32) or {}  # dict: {model_name: score}
                    items = [(k, v) for k, v in scores.items() if not OWW_ALLOW or k in OWW_ALLOW]
                    if any(v >= WAKE_SENSITIVITY for _, v in items):
                        LOG.info("[hotword] ¡Hotword por OWW!")
                        _beep()
                        triggered = True

            # Fallback por ASR si OWW no disparó (anunciar solo una vez)
            if not triggered:
                if not told_fallback:
                    LOG.info("[hotword] ¡Hotword (fallback)!")
                    told_fallback = True

                pcm = _capture_pcm(MAX_LISTEN_SECONDS)
                if vad:
                    pcm = _apply_vad(pcm)
                txt = transcribe(pcm)

                if not txt:
                    LOG.info("[hotword] ASR: transcripción vacía.")
                    time.sleep(COOLDOWN_AFTER_EMPTY)
                    continue

                LOG.info("[hotword] ASR: %r", txt)
                lowered = txt.lower()
                if any(h in lowered for h in HOTWORDS):
                    _beep()
                    _speak_with_tonto(txt)
                    time.sleep(COOLDOWN_AFTER_TRIGGER)
                continue

            # Si OWW disparó, capturamos utterance y lanzamos ASR
            pcm = _capture_pcm(MAX_LISTEN_SECONDS)
            if vad:
                pcm = _apply_vad(pcm)
            txt = transcribe(pcm)
            if not txt:
                LOG.info("[hotword] ASR: transcripción vacía.")
                time.sleep(COOLDOWN_AFTER_EMPTY)
                continue
            LOG.info("[hotword] ASR: %r", txt)
            _speak_with_tonto(txt)
            time.sleep(COOLDOWN_AFTER_TRIGGER)

        except Exception as e:
            LOG.info("[hotword] loop error: %r", e)
            time.sleep(0.5)

if __name__ == "__main__":
    main()
