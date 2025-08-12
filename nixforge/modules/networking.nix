{ config, lib, pkgs, ... }:

{
  networking.hostName = "clembell-server";
  time.timeZone = "Europe/Madrid";

  networking.interfaces.enp2s0f0.useDHCP = true;

  networking.interfaces.enp2s0f1 = {
    useDHCP = false;
    ipv4.addresses = [{ address = "192.168.10.1"; prefixLength = 24; }];
  };

  networking.interfaces.enp4s0 = {
    useDHCP = false;
    ipv4.addresses = [{ address = "192.168.20.1"; prefixLength = 24; }];
  };

  networking.nat = {
    enable = true;
    externalInterface = "enp2s0f0";
    internalInterfaces = [ "enp2s0f1" "enp4s0" "ve-*" "ve+" ];
    forwardPorts = [
      { sourcePort = 8096; destination = "192.168.100.2:8096"; proto = "tcp"; }
      { sourcePort = 9091; destination = "192.168.101.2:9091"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "udp"; }
      { sourcePort = 9090; destination = "192.168.102.2:9090"; proto = "tcp"; }
      { sourcePort = 2022; destination = "192.168.104.2:2022"; proto = "tcp"; }
      { sourcePort = 25565; destination = "192.168.104.2:25565"; proto = "tcp"; }
      { sourcePort = 25565; destination = "192.168.104.2:25565"; proto = "udp"; }
    ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
  };

  boot.kernelModules = [
    "overlay"
    "br_netfilter"
    "nf_conntrack"
    "nf_nat"
    "ip_tables"
    "iptable_nat"
    "x_tables"
  ];

}
