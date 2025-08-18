# nixforge/

This folder contains **modules** (reusable NixOS code) and **containers** (self‑contained services).
Import modules and containers from your `configuration.nix` as needed.

## Layout

```
nixforge/
├─ modules/      # Shared, reusable NixOS modules
└─ containers/   # NixOS containers, one per service
```

## Importing Modules

In your `configuration.nix`:

```nix
{
  imports = [
    ./nixforge/nixforge.nix
  ];
}
```

If you want to import only certain modules, in yout `nixforge.nix` comment the ones that are not required:

```nix
  imports =
    [
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
```

## Managing Containers

- Build and switch the host: `sudo nixos-rebuild switch --flake .`
- List containers: `machinectl list`
- Inspect logs: `journalctl -M <name> -u <unit> -b -n 200 -o cat`
- Shell into a container: `sudo machinectl shell <name>`
