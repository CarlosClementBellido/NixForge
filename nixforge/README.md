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

## Managing Containers

- Build and switch the host: `sudo nixos-rebuild switch --flake .`
- List containers: `machinectl list`
- Inspect logs: `journalctl -M <name> -u <unit> -b -n 200 -o cat`
- Shell into a container: `sudo machinectl shell <name>`
