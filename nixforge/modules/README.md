# NixForge Modules

These modules group reusable configuration to keep `configuration.nix` small and composable.

## Common Modules

- **networking.nix** — Interfaces, LAN/WAN, NAT, firewall, DHCP/DNS.
- **users.nix** — Users and groups, base shell/tools, secure defaults.
- **services.nix** — Shared service policies (e.g., journald, logrotate, hardening).

> Add or remove modules according to your setup. Each module should be self‑contained and well commented.

## Usage

```nix
{
  imports = [
      ./modules/system-packages.nix
      ./modules/users.nix
      ./modules/openssh.nix
      ./modules/networking.nix
      ./modules/firewall.nix
      ./modules/dnsmasq.nix
      ./modules/samba.nix
      ./modules/nginx.nix
      ./modules/containers.nix
      ./modules/nix-ld.nix
      ./modules/metrics-host.nix
      ./modules/environment.nix
      ./modules/systemd.nix
      ./modules/audio.nix
  ];
}
```

## Conventions

- Keep secrets out of modules; read them from `*.cred` (git‑ignored) or NixOS options that you set locally.
- Prefer **idempotent** behavior (create only if missing, avoid destructive defaults).
- Avoid hard‑coding IPs/domains in modules; expose them as options.
