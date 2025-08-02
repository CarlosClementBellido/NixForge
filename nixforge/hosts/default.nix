{ config, pkgs, ... }:

{
  containers = {
    media = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "192.168.100.1";
      localAddress = "192.168.100.2";
      config = import ../containers/media/configuration.nix;

      bindMounts = {
        "/var/media/videos" = {
          hostPath = "/var/media/videos";
          isReadOnly = false;
        };
      };
    };

    torrent = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "192.168.100.1";
      localAddress = "192.168.100.3";
      config = import ../containers/torrent/configuration.nix;

      bindMounts = {
        "/var/media/videos" = {
          hostPath = "/var/media/videos";
          isReadOnly = false;
        };
        "/var/media/watch" = {
          hostPath = "/var/media/watch";
          isReadOnly = false;
        };
        "/var/lib/transmission/.config/transmission-daemon/settings.json" = {
          hostPath = "/etc/nixos/nixforge/transmission-config/settings.json";
          isReadOnly = false;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8096 9091 ];

  networking.nat = {
    enable = true;
    externalInterface = "enp2s0f0"; # ⚠️ Sustituye por tu interfaz real de salida (ver abajo)
    internalInterfaces = [ "ve-+" ]; # Todas las interfaces virtual ethernet de containers
  };

  networking.nat.forwardPorts = [
    {
      proto = "tcp";
      fromPort = 8096;
      toPort = 8096;
      destination = "192.168.100.2";
    }
    {
      proto = "tcp";
      fromPort = 9091;
      toPort = 9091;
      destination = "192.168.100.3";
    }
  ];
}
