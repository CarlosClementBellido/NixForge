{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix

      ./nixforge/modules/system-packages.nix
      ./nixforge/modules/users.nix
      ./nixforge/modules/openssh.nix
      ./nixforge/modules/networking.nix
      ./nixforge/modules/firewall.nix
      ./nixforge/modules/dnsmasq.nix
      ./nixforge/modules/samba.nix
      ./nixforge/modules/nginx.nix
      ./nixforge/modules/containers.nix
      ./nixforge/modules/nix-ld.nix
      ./nixforge/modules/metrics-host.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  system.stateVersion = "24.05";
}
