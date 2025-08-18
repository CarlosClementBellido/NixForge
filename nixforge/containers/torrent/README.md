# Transmission Container

BitTorrent daemon with a web UI, downloading to `/var/media/videos/`.

## Features

- Web UI
- RPC authentication
- Host‑mounted storage

## Secrets

Copy `transmission.cred` to `transmission.cred.example` and set:

```
{
  "rpc-username": "user",
  "rpc-password": "1234"
}
```

## Files

- `configuration.nix` — Container definition and hardening
- `transmission.cred.example` — Secrets template
