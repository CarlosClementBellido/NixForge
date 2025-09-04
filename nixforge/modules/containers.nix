{ config, lib, pkgs, ... }:

{
  containers.media = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.2";
    config = import ../containers/media/configuration.nix;
    bindMounts."/var/media/videos" = {
      hostPath = "/var/media/videos";
      isReadOnly = false;
    };
  };

  containers.torrent = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.101.1";
    localAddress = "192.168.101.2";
    config = import ../containers/torrent/configuration.nix;
    bindMounts."/var/media/videos" = {
      hostPath = "/var/media/videos";
      isReadOnly = false;
    };
  };

  containers.ddns-ionos = {
    autoStart = true;
    privateNetwork = false;
    config = import ../containers/ddns-ionos/configuration.nix;
  };

  containers.dashboard = {
    autoStart = true;
    privateNetwork = true;

    bindMounts."/etc/nginx/html/metrics.json" = {
      hostPath = "/var/lib/metrics/metrics.json";
      isReadOnly = true;
    };

    hostAddress = "192.168.102.1";
    localAddress = "192.168.102.2";
    config = import ../containers/dashboard/configuration.nix;
  };

  containers.cockpit = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.103.1";
    localAddress = "192.168.103.2";

    bindMounts."/run/libvirt" = {
      hostPath = "/run/libvirt";
      isReadOnly = false;
    };

    config = import ../containers/cockpit/configuration.nix;
  };

  containers.pterodactyl = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.104.1";
    localAddress = "192.168.104.2";
    config = import ../containers/pterodactyl/configuration.nix;

    extraFlags = [
      "--private-users=off"
      "--capability=all"
      "--bind-ro=/var/lib/nixos/static-dns/resolv.conf:/etc/resolv.conf"
    ];

    bindMounts."/etc/resolv.conf" = {
      hostPath = "/var/lib/nixos/static-dns/resolv.conf";
      isReadOnly = true;
    };
  };

  containers.tonto = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.105.1";
    localAddress = "192.168.105.2";
    config = import ../containers/tonto/configuration.nix;

    timeoutStartSec = "5min";

    extraFlags = [
      "--bind-ro=/var/lib/nixos/static-dns/resolv.conf:/etc/resolv.conf"
    ];

    bindMounts."/etc/resolv.conf" = {
      hostPath = "/var/lib/nixos/static-dns/resolv.conf";
      isReadOnly = true;
    };

    bindMounts."/etc/secrets/gcp-sa.json" = 
    { 
      hostPath = "/etc/nixos/nixforge/containers/tonto/gcp-sa.json"; 
      isReadOnly = true; 
    };

    bindMounts = {
      "/dev/nvidia0".hostPath = "/dev/nvidia0";
      "/dev/nvidiactl".hostPath = "/dev/nvidiactl";
      "/dev/nvidia-uvm".hostPath = "/dev/nvidia-uvm";
      "/dev/nvidia-uvm-tools".hostPath = "/dev/nvidia-uvm-tools";
      "/run/opengl-driver".hostPath = "/run/opengl-driver"; # libs del driver
    };
  };

  containers.piper-train = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.106.1";
    localAddress = "192.168.106.2";

    # Pasa GPU y librerías del driver al contenedor
    extraFlags = [
      "--bind-ro=/run/opengl-driver:/run/opengl-driver"
      "--bind-ro=/dev/nvidiactl"
      "--bind-ro=/dev/nvidia-uvm"
      "--bind-ro=/dev/nvidia-uvm-tools"
      "--bind-ro=/dev/nvidia-modeset"
      "--bind=/dev/nvidia0"
    ];

    bindMounts = {
      "/var/lib/piper" = { hostPath = "/var/lib/piper"; isReadOnly = false; };
      "/var/lib/piper/models" = {
        hostPath = "/etc/nixos/nixforge/containers/piper-train/models";
        isReadOnly = false; # ahora escribimos metadata.csv y outputs aquí
      };
    };

    # Config del contenedor
    config = import ../containers/piper-train/configuration.nix;
  };

}
