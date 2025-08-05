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
}
