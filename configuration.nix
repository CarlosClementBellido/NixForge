{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix

      ./nixforge/nixforge.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  system.stateVersion = "24.05";
}
