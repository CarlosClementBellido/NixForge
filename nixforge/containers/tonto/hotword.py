#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os, sys, time, wave, math, struct, subprocess
from array import array
from collections import deque

from faster_whisper import WhisperModel

import pyaudio
from RealtimeSTT import AudioToTextRecorder

LANGUAGE        = "es"
MODEL_SIZE      = os.environ.get("WHISPER_MODEL", "small")
DEVICE          = os.environ.get("WHISPER_DEVICE", "cuda")
ASSISTANT_URL   = os.environ.get("ASSISTANT_URL", "http://localhost:8088/speak")
BACKEND_ENV     = os.environ.get("WAKEWORD_BACKEND", "pvporcupine").lower()
USE_PAREC_PIPE  = os.environ.get("USE_PAREC_PIPE", "0") in ("1", "true", "yes")
USE_PORCUPINE_PIPE = os.environ.get("USE_PORCUPINE_PIPE", "0") in ("1", "true", "yes")
PULSE_SERVER    = os.environ.get("PULSE_SERVER", "tcp:192.168.105.1:4713")
PULSE_SOURCE    = os.environ.get("PULSE_SOURCE", "")

KEYWORDS        = [kw.strip() for kw in os.environ.get("WAKEWORDS", "jarvis,computer,alexa").split(",") if kw.strip()]
SENS            = float(os.environ.get("WAKEWORD_SENS", "0.95"))
GAIN_LINEAR     = float(os.environ.get("WAKEWORD_GAIN", "2.0"))

def log_env():
    print("[hotword] ===== ENTORNO =====", flush=True)
    print(f"PULSE_SERVER      = {PULSE_SERVER}", flush=True)
    print(f"PULSE_SOURCE      = {PULSE_SOURCE or '(no definido)'}", flush=True)
    print(f"ASSISTANT_URL     = {ASSISTANT_URL}", flush=True)
    print(f"MODEL/DEVICE      = {MODEL_SIZE}/{DEVICE}", flush=True)
    print(f"BACKEND           = {BACKEND_ENV}", flush=True)
    print(f"USE_PAREC_PIPE    = {USE_PAREC_PIPE}", flush=True)
    print(f"USE_PORCUPINE_PIPE= {USE_PORCUPINE_PIPE}", flush=True)
    print(f"KEYWORDS          = {KEYWORDS}  sens={SENS}  gain={GAIN_LINEAR}x", flush=True)
    print("[hotword] ===================", flush=True)

def gen_beep_wav(path="/tmp/wake_beep.wav", hz=880, dur=0.12, rate=16000, vol=0.6):
    try:
        if os.path.exists(path): return path
        n = int(rate * dur); frames = []
        for i in range(n):
            s = vol * math.sin(2.0 * math.pi * hz * (i / float(rate)))
            frames.append(int(max(-1.0, min(1.0, s)) * 32767.0))
        with wave.open(path, "wb") as wf:
            wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(rate)
            wf.writeframes(struct.pack("<" + "h"*len(frames), *frames))
        return path
    except Exception as e:
        print(f"[hotword] beep wav error: {e}", flush=True); return None

def play_beep():
    try:
        wav = gen_beep_wav()
        if wav: subprocess.Popen(["aplay", "-q", wav])
    except Exception as e:
        print(f"[hotword] beep error: {e}", flush=True)

def vu_of_int16(pcm: array):
    if not pcm: return (0.0, 0)
    acc = 0.0; peak = 0
    for v in pcm:
        av = abs(v); peak = max(peak, av); acc += float(v)*float(v)
    rms = math.sqrt(acc / len(pcm))
    return (rms, peak)

def clamp_int16(x: int) -> int:
    if x > 32767: return 32767
    if x < -32768: return -32768
    return x

def list_pyaudio_devices():
    pa = pyaudio.PyAudio()
    pulse_idx, first_input = None, None
    try:
        n = pa.get_device_count()
        print(f"[hotword] PyAudio devices: {n}", flush=True)
        for i in range(n):
            info = pa.get_device_info_by_index(i)
            name = (info.get("name") or "")
            max_in = int(info.get("maxInputChannels") or 0)
            print(f"  - #{i}: '{name}' inputs={max_in}", flush=True)
            if max_in > 0 and first_input is None:
                first_input = i
            if "pulse" in name.lower() or "pulseaudio" in name.lower():
                pulse_idx = i
        return (pulse_idx if pulse_idx is not None else first_input, pa)
    except Exception:
        pa.terminate()
        raise

def preflight_parec(secs=1, rate=16000):
    cmd = ["parec"]
    if PULSE_SOURCE: cmd += ["-d", PULSE_SOURCE]
    cmd += ["--rate", str(rate), "--format", "s16le", "--channels", "1"]
    print(f"[hotword] preflight parec: {' '.join(cmd)}", flush=True)
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=0)
    except FileNotFoundError:
        print("[hotword] parec no está en PATH", flush=True); return False
    got = array('h')
    end = time.time() + secs
    frame_bytes = 1024 * 2
    while time.time() < end:
        chunk = proc.stdout.read(frame_bytes)
        if not chunk: break
        pcm = array('h'); pcm.frombytes(chunk); got.extend(pcm)
    proc.kill()
    rms, peak = vu_of_int16(got)
    print(f"[hotword] preflight parec RMS={rms:.1f} PEAK={peak}", flush=True)
    return len(got) > 0

def run_rtsst_normal():
    print("[hotword] modo: RealtimeSTT wakeword (PyAudio)", flush=True)
    dev_index, pa = list_pyaudio_devices()
    if dev_index is None:
        print("[hotword] ERROR: sin dispositivos de entrada", flush=True); return
    preflight_parec(secs=1, rate=16000)
    pa.terminate()

    common = dict(
        model=MODEL_SIZE, language=LANGUAGE, device=DEVICE,
        on_wakeword_detection_start=lambda: print("[hotword] → escuchando wakeword…", flush=True),
        on_wakeword_detection_end=lambda:   print("[hotword] ← deja de escuchar wakeword", flush=True),
        on_wakeword_detected=lambda: (print("[hotword] WAKEWORD DETECTADA", flush=True), play_beep()),
        on_recording_start=lambda: print("[hotword] ▶ grabación", flush=True),
        on_recording_stop=lambda:  print("[hotword] ■ fin grabación", flush=True),
        on_recorded_chunk=lambda b: (lambda r,p: print(f"[VU] rms={r:.1f} peak={p}", flush=True))(*vu_of_bytes(b)),
        wake_words_sensitivity=SENS,
        wake_word_buffer_duration=0.6,
        wake_word_activation_delay=0.0,
        silero_sensitivity=0.6,
        webrtc_sensitivity=2,
        enable_realtime_transcription=False,
        input_device_index=dev_index,
    )

    def vu_of_bytes(b):
        pcm = array('h'); pcm.frombytes(b or b""); return vu_of_int16(pcm)

    recorder = None
    if BACKEND_ENV == "oww":
        recorder = AudioToTextRecorder(wakeword_backend="oww", openwakeword_model_paths="", **common)
    if recorder is None:
        recorder = AudioToTextRecorder(wakeword_backend="pvporcupine", wake_words=",".join(KEYWORDS), **common)

    print(f"🎤 Di {KEYWORDS} …", flush=True)
    import requests
    while True:
        try:
            txt = recorder.text()
            if not txt or not txt.strip(): continue
            q = txt.strip(); print(f"🗣️  {q}", flush=True)
            try:
                r = requests.post(ASSISTANT_URL, json={"question": q}, timeout=60)
                if r.status_code != 200:
                    print(f"[hotword] Assistant HTTP {r.status_code}: {r.text}", flush=True)
            except Exception as e:
                print(f"[hotword] error enviando a assistant: {e}", flush=True)
        except KeyboardInterrupt:
            print("[hotword] detenido por usuario.", flush=True); break
        except Exception as e:
            print(f"[hotword] loop error: {e}", flush=True); time.sleep(1)

def _load_whisper_safely():
    want_device = DEVICE
    try:
        if want_device.lower() == "cuda":
            print(f"[hotword] cargando faster-whisper: {MODEL_SIZE} (float32) en cuda …", flush=True)
            return WhisperModel(MODEL_SIZE, device="cuda", compute_type="float32")
        else:
            print(f"[hotword] cargando faster-whisper: {MODEL_SIZE} (int8) en cpu …", flush=True)
            return WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
    except RuntimeError as e:
        msg = str(e)
        print(f"[hotword] aviso al cargar en {want_device}: {msg}", flush=True)
        print("[hotword] fallback → CPU int8", flush=True)
        return WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")

def run_pipe_porcupine():
    """PAREC + Porcupine (no bloqueante) + grabación propia + transcripción con faster-whisper."""
    print("[hotword] modo: PAREC + Porcupine + faster-whisper (EOS por silencio)", flush=True)

    print("[hotword] modo: PAREC + Porcupine + faster-whisper (EOS por silencio)", flush=True)
    model = _load_whisper_safely()
    print("[hotword] faster-whisper listo.", flush=True)

    cmd = ["parec"]
    if PULSE_SOURCE:
        cmd += ["-d", PULSE_SOURCE]
    cmd += ["--rate", "16000", "--format", "s16le", "--channels", "1"]
    print(f"[hotword] exec: {' '.join(cmd)}", flush=True)
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, bufsize=0)
    except FileNotFoundError:
        print("[hotword] ERROR: parec no disponible", flush=True)
        return

    try:
        import pvporcupine
    except Exception as e:
        print("[hotword] ERROR: pvporcupine no está instalado:", e, flush=True)
        proc.terminate()
        return
    porcupine = pvporcupine.create(keywords=KEYWORDS, sensitivities=[SENS]*len(KEYWORDS))
    RATE  = porcupine.sample_rate      # 16000
    FRAME = porcupine.frame_length     # 512 (32ms)
    BYTES_PER_SAMPLE = 2
    print(f"[hotword] Porcupine rate={RATE} frame={FRAME}", flush=True)
    print(f"🎤 Di {KEYWORDS} …", flush=True)
    play_beep()
    play_beep()
    play_beep()

    from array import array
    def read_exact(nbytes: int) -> bytes:
        buf = b""
        while len(buf) < nbytes:
            chunk = proc.stdout.read(nbytes - len(buf))
            if not chunk:
                break
            buf += chunk
        return buf

    vu_bucket = array('h')
    next_vu_ts = 0.0
    def feed_vu(raw_bytes: bytes, apply_gain: bool) -> array:
        nonlocal vu_bucket, next_vu_ts
        pcm = array('h')
        if raw_bytes:
            pcm.frombytes(raw_bytes)
            if apply_gain and GAIN_LINEAR != 1.0:
                for i, v in enumerate(pcm):
                    pcm[i] = clamp_int16(int(v * GAIN_LINEAR))
        # VU cada ~1s
        now = time.time()
        vu_bucket.extend(pcm)
        if now >= next_vu_ts:
            rms, peak = vu_of_int16(vu_bucket)
            print(f"[VU] rms={rms:.1f} peak={peak}", flush=True)
            vu_bucket = array('h')
            next_vu_ts = now + 1.0
        return pcm

    MIN_TALK_SEC           = float(os.environ.get("MIN_TALK_SEC", "0.6"))
    MAX_CMD_SEC            = float(os.environ.get("MAX_CMD_SEC",  "8"))
    SILENCE_RMS_THRESHOLD  = float(os.environ.get("SILENCE_RMS",  "700"))
    SILENCE_HANG_SEC       = float(os.environ.get("SILENCE_HANG", "0.8"))

    min_frames_rec   = int((RATE / FRAME) * MIN_TALK_SEC)
    max_frames_rec   = int((RATE / FRAME) * MAX_CMD_SEC)
    silence_frames   = int((RATE / FRAME) * SILENCE_HANG_SEC)

    try:
        while True:
            raw = read_exact(FRAME * BYTES_PER_SAMPLE)
            if not raw:
                if proc.poll() is not None:
                    print("[hotword] parec terminó", flush=True)
                    break
                time.sleep(0.005)
                continue

            pcm = feed_vu(raw, apply_gain=True)
            try:
                idx = porcupine.process(pcm)
            except Exception as e:
                print(f"[hotword] porcupine.process error: {e}", flush=True)
                idx = -1

            if idx < 0:
                continue

            print(f"[hotword] WAKEWORD DETECTADA: {KEYWORDS[idx]} (idx={idx})", flush=True)
            play_beep()

            recorded = array('h')
            frames_seen     = 0
            silent_in_a_row = 0
            started_ts      = time.time()
            preroll = int(RATE / FRAME * 0.3)

            for _ in range(preroll):
                r = read_exact(FRAME * BYTES_PER_SAMPLE)
                if not r: break
                p = feed_vu(r, apply_gain=False)
                recorded.extend(p)
                frames_seen += 1

            print("[hotword] ▶ grabación", flush=True)

            while True:
                r = read_exact(FRAME * BYTES_PER_SAMPLE)
                if not r:
                    if proc.poll() is not None:
                        print("[hotword] parec terminó durante grabación", flush=True)
                        break
                    time.sleep(0.002)
                    continue

                p = feed_vu(r, apply_gain=False)
                recorded.extend(p)
                frames_seen += 1

                rms, peak = vu_of_int16(p)
                if rms < SILENCE_RMS_THRESHOLD and frames_seen > min_frames_rec:
                    silent_in_a_row += 1
                else:
                    silent_in_a_row = 0

                if silent_in_a_row >= silence_frames:
                    print("[hotword] ■ fin grabación (silencio)", flush=True)
                    break
                if frames_seen >= max_frames_rec:
                    print("[hotword] ■ fin grabación (max timeout)", flush=True)
                    break

            if len(recorded) == 0:
                print("[hotword] nada grabado; vuelvo a wake", flush=True)
                continue

            import numpy as np
            pcm_np = np.asarray(recorded, dtype=np.int16).astype(np.float32) / 32768.0

            print(f"[hotword] transcribiendo… muestras={len(pcm_np)} (~{len(pcm_np)/RATE:.2f}s)", flush=True)
            segments, info = model.transcribe(pcm_np, language=LANGUAGE, vad_filter=False, beam_size=5)
            text = "".join(seg.text for seg in segments).strip()
            print(f"🗣️  {text if text else '(vacío)'}", flush=True)

            if text:
                try:
                    import requests
                    r = requests.post(ASSISTANT_URL, json={"question": text}, timeout=60)
                    if r.status_code != 200:
                        print(f"[hotword] Assistant HTTP {r.status_code}: {r.text}", flush=True)
                except Exception as e:
                    print(f"[hotword] error enviando a assistant: {e}", flush=True)

            print(f"[hotword] listo; escuchando wakeword otra vez.", flush=True)

    except KeyboardInterrupt:
        print("[hotword] detenido por usuario.", flush=True)
    finally:
        try: porcupine.delete()
        except Exception: pass
        try: proc.terminate()
        except Exception: pass

def main():
    print("[hotword] iniciando…", flush=True)
    log_env()
    if USE_PORCUPINE_PIPE:
        run_pipe_porcupine()
    elif USE_PAREC_PIPE:
        print("[hotword] AVISO: USE_PAREC_PIPE está obsoleto aquí; usa USE_PORCUPINE_PIPE=1", flush=True)
        run_pipe_porcupine()
    else:
        run_rtsst_normal()

if __name__ == "__main__":
    main()
