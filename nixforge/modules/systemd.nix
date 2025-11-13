{ lib, ... }:

{
  systemd.services."container@pterodactyl" = {
    serviceConfig = {
      KeyringMode = "inherit";
      SystemCallFilter = "";
      NoNewPrivileges = false;
    };
    environment.SYSTEMD_NSPAWN_UNIFIED_HIERARCHY = "1";
  };

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

  systemd.user.services."pipewire-pulse" = {
    enable = true;
    description = "PipeWire PulseAudio (always on)";
    after = [ "pipewire.service" ];
    serviceConfig = {
      Restart = "always";
    };
    wantedBy = [ "default.target" ];
  };

  systemd.network.networks."30-lan10g0" = {
    matchConfig.Name = "lan10g0";
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6AcceptRA = false;
      KeepConfiguration = "static";
    };
    linkConfig.RequiredForOnline = false;
    address = [ "192.168.10.1/24" ];
  };

  systemd.network.networks."30-lan1g0" = {
    matchConfig.Name = "lan1g0";
    networkConfig = {
      ConfigureWithoutCarrier = true;
      IPv6AcceptRA = false;
      KeepConfiguration = "static";
    };
    linkConfig.RequiredForOnline = false;
    address = [ "192.168.20.1/24" ];
  };
}