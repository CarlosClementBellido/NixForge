# NixForge

NixForge is a modular, **declarative NixOS** infrastructure intended to run on a single host.
It turns your NixOS machine into a **router + media + gaming + utilities** server using
isolated NixOS containers and reusable Nix modules.

## Highlights

- **Declarative**: everything is committed as code. Rebuilds are reproducible.
- **Secure by design**: services live in their own NixOS containers.
- **Networking built‑in**: NAT, DHCP, firewall, DNS.
- **Plug & Play** services: Cockpit, Dashboard, DDNS (IONOS), Jellyfin, Pterodactyl, Tonto (voice assistant), Transmission.
- **Modular docs**: each container and module ships with its own README.

## Repository Layout

```
.
├─ configuration.nix
├─ hardware-configuration.nix
└─ nixforge/
   ├─ modules/
   └─ containers/
```

## Quick Start

1) Clone and inspect:

```bash
git clone https://github.com/CarlosClementBellido/NixForge.git
cd NixForge
```

2) Review `configuration.nix` and the `nixforge/*` imports.

3) Build and switch:

```bash
sudo nixos-rebuild switch --flake .
```

4) List and enter containers:

```bash
machinectl list
sudo machinectl shell <container-name>
```

## Containers Overview

| Container       | Purpose                                           |
|-----------------|---------------------------------------------------|
| cockpit         | Web admin UI and virtual machines management      |
| dashboard       | Real-time metrics dashboard                       |
| ddns-ionos      | Dynamic DNS updater for IONOS                     |
| jellyfin        | Media server (CPU-only)                           |
| pterodactyl     | Game servers controller panel                     |
| tonto           | Voice/AI assistant (FastAPI + Vertex AI + Piper)  |
| transmission    | BitTorrent client with web UI                     |

## License

MIT. See headers and individual folders for details.
