{ config, pkgs, lib, ... }:

{
  systemd.services.transmission = {
    description = "Transmission BitTorrent Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/transmission/.config/transmission-daemon";
      ExecStart = "${pkgs.transmission}/bin/transmission-daemon -f --log-info --config-dir /etc/transmission-daemon";
      Restart = "on-failure";
      User = "root";

      ProtectSystem = "no";
      ProtectHome = "no";
      PrivateTmp = false;
      ReadWritePaths = [ "/" ];
    };
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 9091 51413 ];
  networking.firewall.allowedUDPPorts = [ 51413 ];
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # settings.json correcto desde el inicio
  environment.etc."transmission-daemon/settings.json".text = builtins.toJSON {
    "download-dir" = "/var/media/videos";
    "rpc-bind-address" = "0.0.0.0";
    "rpc-enabled" = true;
    "rpc-port" = 9091;
    "rpc-whitelist-enabled" = false;
    "rpc-authentication-required" = false;
    "peer-port" = 51413;
    "port-forwarding-enabled" = true;
    "dht-enabled" = true;
    "pex-enabled" = true;
    "lpd-enabled" = true;
  };

  system.stateVersion = "24.05";
}
