{ config, lib, pkgs, ... }:

{
  networking.hostName = "clembell-server";
  time.timeZone = "Europe/Madrid";

  # Usar systemd-networkd (traduce networking.interfaces a .network)
  networking.useNetworkd = true;

  # Nombres de interfaz estables por MAC (udev .link)
  systemd.network.links = {
    "10-wan0" = {
      matchConfig.PermanentMACAddress = "a0:36:9f:e6:97:5c";
      linkConfig.Name = "wan0";
    };
    "10-lan10g0" = {
      matchConfig.PermanentMACAddress = "a0:36:9f:e6:97:5e";
      linkConfig.Name = "lan10g0";
    };
    "10-lan1g0" = {
      matchConfig.PermanentMACAddress = "00:e0:24:6f:32:ae";
      linkConfig.Name = "lan1g0";
    };
  };

  # Config de interfaces (networkd)
  networking.interfaces.wan0.useDHCP = true;

  networking.interfaces.lan10g0 = {
    useDHCP = false;
    ipv4.addresses = [ { address = "192.168.10.1"; prefixLength = 24; } ];
  };

  networking.interfaces.lan1g0 = {
    useDHCP = false;
    ipv4.addresses = [ { address = "192.168.20.1"; prefixLength = 24; } ];
  };

  # NAT (sale por wan0; entra por ambas LAN + contenedores ve-*)
  networking.nat = {
    enable = true;
    externalInterface = "wan0";
    internalInterfaces = [ "lan10g0" "lan1g0" "ve-*" "ve+" "wg0" ];
    forwardPorts = [
      { sourcePort = 8096;  destination = "192.168.100.2:8096";  proto = "tcp"; }
      { sourcePort = 9091;  destination = "192.168.101.2:9091"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "udp"; }
      { sourcePort = 9090;  destination = "192.168.102.2:9090"; proto = "tcp"; }
      { sourcePort = 2022;  destination = "192.168.104.2:2022"; proto = "tcp"; }
      { sourcePort = 25565; destination = "192.168.104.2:25565"; proto = "tcp"; }
      { sourcePort = 25565; destination = "192.168.104.2:25565"; proto = "udp"; }
    ];
  };

  # Sysctl recomendados para routing/NAT
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # (Opcional) Módulos; puedes dejarlos si ya te funcionan reglas iptables
  boot.kernelModules = [
    "overlay" "br_netfilter" "nf_conntrack" "nf_nat" "ip_tables" "iptable_nat" "x_tables" "wireguard"
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/wg-easy 0750 root root -"
    "d /dev/net 0755 root root -"
  ];

}
