{ config, lib, pkgs, ... }:

{
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

  system.stateVersion = "24.05";
}
