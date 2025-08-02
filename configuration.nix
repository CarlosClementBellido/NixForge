{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostName = "clembell-server";
  time.timeZone = "Europe/Madrid";

  environment.systemPackages = with pkgs; [ vim wget git ];

  networking.useDHCP = true;

  # Interfaces LAN estáticas 
  networking.interfaces.enp2s0f1.useDHCP = false;
  networking.interfaces.enp2s0f1.ipv4.addresses = [{
    address = "192.168.10.1";
    prefixLength = 24;
  }];

  networking.interfaces.enp4s0.useDHCP = false;
  networking.interfaces.enp4s0.ipv4.addresses = [{
    address = "192.168.20.1";
    prefixLength = 24;
  }];

  # Reenvío de paquetes
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;

  # NAT
  networking.nat = {
    enable = true;
    externalInterface = "enp2s0f0";
    internalInterfaces = [ "enp2s0f1" "enp4s0" "ve-*" ];
    forwardPorts = [
      { sourcePort = 8096; destination = "192.168.100.2:8096"; proto = "tcp"; }
      { sourcePort = 9091; destination = "192.168.101.2:9091"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "udp"; }
    ];
  };

  # DNS y DHCP en ambas LANs
    services.dnsmasq = {
  enable = true;
  settings = {
    interface = [ "enp2s0f1" "enp4s0" ];
    bind-dynamic = true;
    listen-address = "192.168.10.1,192.168.20.1";
    no-dhcp-interface = "lo";

    domain-needed = true;
    bogus-priv = true;

    dhcp-range = [
      "192.168.10.50,192.168.10.150,12h"
      "192.168.20.50,192.168.20.150,12h"
    ];

    dhcp-option = [
      # Opciones para 192.168.10.0/24
      "tag:enp2s0f1,3,192.168.10.1"
      "tag:enp2s0f1,6,1.1.1.1,8.8.8.8"

      # Opciones para 192.168.20.0/24
      "tag:enp4s0,3,192.168.20.1"
      "tag:enp4s0,6,1.1.1.1,8.8.8.8"
    ];

    log-dhcp = true;
    dhcp-broadcast = true;
  };
};


  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  users.users.clement = {
    isNormalUser = true;
    description = "Clement";
    extraGroups = [ "wheel" ];
    initialPassword = "1234";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGkOzjRJ+C1RqylmB8PbyrV0d8UCz09+3Ss4V0KRaIKL clembell-server"
    ];
  };

  # Contenedor Jellyfin
  containers.media = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.1";
    localAddress = "192.168.100.2";
    config = import ./nixforge/containers/media/configuration.nix;
    bindMounts."/var/media/videos" = {
      hostPath = "/var/media/videos";
      isReadOnly = false;
    };
  };

  # Contenedor Transmission
  containers.torrent = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.101.1";
    localAddress = "192.168.101.2";
    config = import ./nixforge/containers/torrent/configuration.nix;
    bindMounts."/var/media/videos" = {
      hostPath = "/var/media/videos";
      isReadOnly = false;
    };
  };

  # Reglas de firewall y reenvío
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8096 9091 51413 ];
    allowedUDPPorts = [ 51413 ];
    trustedInterfaces = [ "enp2s0f1" "enp4s0" ];
    extraCommands = ''
      iptables -A FORWARD -i enp2s0f1 -o enp2s0f0 -j ACCEPT
      iptables -A FORWARD -i enp2s0f0 -o enp2s0f1 -m state --state RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -i enp4s0 -o enp2s0f0 -j ACCEPT
      iptables -A FORWARD -i enp2s0f0 -o enp4s0 -m state --state RELATED,ESTABLISHED -j ACCEPT

      iptables -A FORWARD -i ve-* -o enp2s0f0 -j ACCEPT
      iptables -A FORWARD -i enp2s0f0 -o ve-* -m state --state RELATED,ESTABLISHED -j ACCEPT

      iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o enp2s0f0 -j MASQUERADE
      iptables -t nat -A POSTROUTING -s 192.168.20.0/24 -o enp2s0f0 -j MASQUERADE
      iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o enp2s0f0 -j MASQUERADE
      iptables -t nat -A POSTROUTING -s 192.168.101.0/24 -o enp2s0f0 -j MASQUERADE
    '';
  };

  services.samba = {
    enable = true;
    openFirewall = true; # abre puertos SMB automáticamente
    shares = {
      server = {
        path = "/";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes"; # acceso sin contraseña (puedes quitarlo si quieres login)
      };
    };
  };

  services.samba-wsdd = {
    enable = true; # para que aparezca automáticamente en "Red" en Windows
    openFirewall = true;
  };

  programs.nix-ld.enable = true; 
  programs.nix-ld.libraries = with pkgs; [ 
    zlib
    openssl
    curl 
  ];

  system.stateVersion = "24.05";
}
