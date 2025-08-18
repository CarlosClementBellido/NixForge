# Tonto Container (Voice/AI Assistant)

Container running a FastAPI application that bridges **Vertex AI** (Gemini) and **Piper TTS** for
a lightweight voice assistant you can query via HTTP.

## Features

- Text generation via Vertex AI (service account based)
- Text‑to‑speech via Piper (local model)
- Health endpoints and `/speak` API
- Systemd venv bootstrapper with pinned deps

## Network & Access

- Internal HTTP port (exposed only to host)
- Reverse‑proxy from host if desired: `/tts-info`, `/speak`

## Files

- `configuration.nix` — Container and units

## Troubleshooting

- Missing `libstdc++.so.6` in venv wheels ⇒ add `gcc.cc.lib`/`stdenv.cc.cc.lib` to runtime env or wrap.
- Network not up during venv install ⇒ ensure proper `After=` and retries in bootstrap unit.
- Use: `journalctl -M tonto -u tonto.service -b -n 200 -o cat`
