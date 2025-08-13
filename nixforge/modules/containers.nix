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

    # Evita userns (-U) y fija DNS del contenedor en solo lectura
    extraFlags = [
      "--private-users=off"  # SIN userns
      "--capability=all"
      "--bind-ro=/var/lib/nixos/static-dns/resolv.conf:/etc/resolv.conf"
    ];

    bindMounts."/etc/resolv.conf" = {
      hostPath = "/var/lib/nixos/static-dns/resolv.conf";
      isReadOnly = true;
    };
  };
  
  systemd.services."container@pterodactyl" = {
    serviceConfig = {
      KeyringMode = "inherit";
      SystemCallFilter = "";
      NoNewPrivileges = false;
    };
    environment.SYSTEMD_NSPAWN_UNIFIED_HIERARCHY = "1";
  };

  environment.etc."systemd/nspawn/pterodactyl.nspawn".text = ''
    [Exec]
    # Permitir syscalls de keyring y bpf para Docker/Containerd
    SystemCallFilter=add_key keyctl bpf
  '';

  # Usa nspawn sin -U a nivel global (como ya lo tenías)
  systemd.services."systemd-nspawn@".serviceConfig.ExecStart = lib.mkForce [
    ""
    "systemd-nspawn --quiet --keep-unit --boot --link-journal=try-guest --network-veth --settings=override --machine=%i"
  ];
  
  systemd.services."systemd-nspawn@".serviceConfig = {
    PrivateUsers = false;
    NoNewPrivileges = false;
    KeyringMode = "inherit";
    ProtectControlGroups = false;
    ProtectKernelModules = false;
    ProtectKernelTunables = false;
    RestrictNamespaces = "";
  };

}
