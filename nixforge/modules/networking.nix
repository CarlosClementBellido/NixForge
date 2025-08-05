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
    internalInterfaces = [ "enp2s0f1" "enp4s0" "ve-*" ];
    forwardPorts = [
      { sourcePort = 8096; destination = "192.168.100.2:8096"; proto = "tcp"; }
      { sourcePort = 9091; destination = "192.168.101.2:9091"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "tcp"; }
      { sourcePort = 51413; destination = "192.168.100.2:51413"; proto = "udp"; }
      { sourcePort = 9090; destination = "192.168.102.2:9090"; proto = "tcp"; }
    ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
}
