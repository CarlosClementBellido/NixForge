{ config, pkgs, ... }:

{
  networking.firewall.allowedTCPPorts = [ 8096 ];
  networking.firewall.enable = true;

  services.jellyfin = {
    enable = true;
  };

  system.stateVersion = "24.05";
}
