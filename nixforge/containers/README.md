# NixForge Containers

Each folder here defines a **self‑contained NixOS container**. Containers isolate services, simplify
upgrades and make troubleshooting cleaner.

## Lifecycle

- **Start/Stop**: `machinectl start|stop <name>`
- **Status**: `machinectl status <name>` / `systemctl -M <name> status <unit>`
- **Logs**: `journalctl -M <name> -u <unit> -b -n 200 -o cat`
- **Shell**: `sudo machinectl shell <name>`

## Secrets

Each container that needs secrets has a `*.cred.example`. Copy to its non‑example filename and fill
your values. Ensure the real `*.cred` files are **git‑ignored**.

## Network

Containers usually live on a private bridge and are reverse‑proxied from the host via Nginx.
Expose only what’s necessary; prefer internal communication.
