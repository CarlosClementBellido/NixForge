# NixForge

NixForge is a modular, **declarative NixOS** infrastructure intended to run on a single host.
It turns your NixOS machine into a **router + media + gaming + utilities** server using
isolated NixOS containers and reusable Nix modules.
Every container is managed by Nginx under a domain so please be sure to replace the domain used in the containers with yours.

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

## Hardware used

  * [MOUGOl X99 dual intel Xeon E5 2680 V4 + DDR4 64GB (4*16GB) LGA2011-3 M.2 NVME](https://es.aliexpress.com/item/1005008694023094.html)
  * [CPU cooler PWM](https://es.aliexpress.com/item/1005002733070463.html) x2
  * [M2 SSD NVMe 256GB Goldenfir M.2 PCIe](https://es.aliexpress.com/item/1005005067841102.html)
  * [X540-T2 Chipset Intel PCIe x8 10 Gbps PCIE-X8 X16](https://es.aliexpress.com/item/1005005968543474.html)
  * [NVIDIA Quadro P620 2G](https://es.aliexpress.com/item/1005009411170416.html)
  * [6W speakers](https://es.aliexpress.com/item/1005009173612075.html)
  * [Conference microphone](https://es.aliexpress.com/item/1005006712859510.html)
  * [T.F.SKYWINDINTL 1000W](https://es.aliexpress.com/item/1005007987735357.html)

## License

MIT. See headers and individual folders for details.
