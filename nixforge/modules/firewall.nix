{ ... }:

{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 8096 9091 51413 80 443 ];
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
}
