# CREDITS!! https://fictionbecomesfact.com/notes/cockpit-machines-nixos-setup/
# To edit use your text editor application, for example Nano
{ pkgs, ... }:

{
  virtual-machines = pkgs.callPackage ./virtual-machines.nix { };
  # podman-containers = pkgs.callPackage ./podman-containers.nix { };
}